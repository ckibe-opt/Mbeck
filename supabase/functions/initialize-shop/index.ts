// Follows Supabase Edge Functions Deno runtime
// Deploy with: supabase functions deploy initialize-shop

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0";
import { crypto } from "https://deno.land/std@0.177.0/crypto/mod.ts";
import { encode as hexEncode } from "https://deno.land/std@0.177.0/encoding/hex.ts";

const STARTER_PACK = [
    { name: 'Coca-Cola 500ml', category: 'Drinks', sellingPrice: 70, stock: 24 },
    { name: 'Bread (Festive/Supa Loaf)', category: 'Food', sellingPrice: 85, stock: 10 },
    { name: 'Milk 500ml', category: 'Dairy', sellingPrice: 65, stock: 12 },
    { name: 'Sugar 1kg', category: 'Pantry', sellingPrice: 220, stock: 5 },
    { name: 'Cooking Oil 1L', category: 'Pantry', sellingPrice: 350, stock: 3 },
    { name: 'Maize Flour 2kg', category: 'Food', sellingPrice: 210, stock: 5 },
    { name: 'Safaricom Airtime 50', category: 'Airtime', sellingPrice: 50, stock: 100 },
    { name: 'Safaricom Airtime 100', category: 'Airtime', sellingPrice: 100, stock: 100 },
    { name: 'Royco Cubes', category: 'Spices', sellingPrice: 10, stock: 50 },
    { name: 'Salt 500g', category: 'Pantry', sellingPrice: 30, stock: 10 },
    { name: 'Matchbox', category: 'Household', sellingPrice: 5, stock: 20 },
    { name: 'Blue Band 100g', category: 'Pantry', sellingPrice: 60, stock: 6 },
    { name: 'Eggs (Tray)', category: 'Food', sellingPrice: 450, stock: 2 },
    { name: 'Omo 500g', category: 'Cleaning', sellingPrice: 180, stock: 5 },
    { name: 'Bar Soap', category: 'Cleaning', sellingPrice: 150, stock: 10 },
    { name: 'Tissue Paper', category: 'Household', sellingPrice: 40, stock: 24 },
    { name: 'Pens (Bic)', category: 'Stationery', sellingPrice: 20, stock: 20 },
    { name: 'Exercise Book (96pg)', category: 'Stationery', sellingPrice: 70, stock: 10 },
    { name: 'Yoghurt 250ml', category: 'Dairy', sellingPrice: 80, stock: 8 },
    { name: 'Mineral Water 500ml', category: 'Drinks', sellingPrice: 40, stock: 24 },
];

serve(async (req) => {
    try {
        // 1. Auth Check
        const authHeader = req.headers.get('Authorization');
        if (!authHeader) {
            return new Response(JSON.stringify({ error: 'Missing Authorization header' }), { status: 401 });
        }

        // Initialize Client with Service Role (needs privileges to check events for idempotency or write to locked tables)
        // Actually, usually user token is enough if RLS allows writing to their own events.
        // But to be safe and robust, we use Service Role for "System Actions".
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
        const supabase = createClient(supabaseUrl, supabaseServiceKey);

        // Verify User
        const { data: { user }, error: authError } = await supabase.auth.getUser(authHeader.replace('Bearer ', ''));
        if (authError || !user) {
            return new Response(JSON.stringify({ error: 'Invalid Token' }), { status: 401 });
        }

        const userId = user.id;
        const shopId = userId; // Assuming 1-to-1 mapping for MVP

        console.log(`🚀 Initializing Shop for User: ${userId}`);

        // 2. Check if already initialized (Idempotency)
        // Check if we have any INVENTORY_CREATE events for this shop from 'system_seeder_edge'
        const { count } = await supabase
            .from('events')
            .select('*', { count: 'exact', head: true })
            .eq('shop_id', shopId)
            .eq('device_id', 'system_seeder_edge');

        if (count && count > 0) {
            return new Response(JSON.stringify({ message: 'Shop already initialized', count }), {
                headers: { 'Content-Type': 'application/json' },
                status: 200
            });
        }

        // 3. Generate Events & Inventory
        const eventsToInsert = [];
        const inventoryToInsert = [];
        const timestamp = Date.now();

        for (const item of STARTER_PACK) {
            const payload = {
                name: item.name,
                category: item.category,
                sellingPrice: item.sellingPrice,
                originalPrice: 0,
                stock: item.stock,
                imagePath: '',
            };

            const eventId = crypto.randomUUID();
            const eventType = 'INVENTORY_CREATE';
            const deviceId = 'system_seeder_edge';

            // Canonical encode + Hash
            const rawString = encodeCanonical(payload);
            const hashInput = `${eventId}|${eventType}|${rawString}|${timestamp}|${shopId}|${deviceId}`;

            // Hash SHA-256
            const msgUint8 = new TextEncoder().encode(hashInput);
            const hashBuffer = await crypto.subtle.digest('SHA-256', msgUint8);
            const hash = new TextDecoder().decode(hexEncode(new Uint8Array(hashBuffer)));

            eventsToInsert.push({
                id: eventId,
                event_type: eventType,
                payload: payload,
                payload_raw: rawString,
                hash: hash,
                timestamp: timestamp,
                shop_id: shopId,
                device_id: deviceId,
                synced: 1,
                sync_attempts: 0,
                failed: 0,
            });

            inventoryToInsert.push({
                ...item,
                shop_id: shopId,
                specification: 'Standard',
                barcode: '',
                imagePath: '',
                sellingPrice: item.sellingPrice, // ensure camelCase matches DB column if quotes used
                originalPrice: 0,
            });
        }

        // 4. Batch Insert
        // Events
        const { error: eventError } = await supabase.from('events').insert(eventsToInsert);
        if (eventError) {
            throw eventError;
        }

        // Inventory View
        const { error: invError } = await supabase.from('inventory').upsert(inventoryToInsert, { onConflict: 'shop_id, name' });
        if (invError) {
            throw invError;
        }

        return new Response(JSON.stringify({ message: 'Success', items: STARTER_PACK.length }), {
            headers: { 'Content-Type': 'application/json' },
            status: 200,
        });

    } catch (err) {
        return new Response(JSON.stringify({ error: err.message }), { status: 500 });
    }
});

// Helper: Canonical JSON Encoding (Matches Dart logic)
// Sort keys -> JSON stringify
function encodeCanonical(obj: any): string {
    if (typeof obj !== 'object' || obj === null) {
        return JSON.stringify(obj);
    }

    if (Array.isArray(obj)) {
        // Determine if array of objects needs recursive sort? 
        // Dart implementation: sorted[key] = value.map(...)
        // Assuming simplistic payload where we don't have arrays or if we do, they are simple.
        // But to match exactly:
        const arr = obj.map(item => {
            if (typeof item === 'object' && item !== null) {
                return JSON.parse(encodeCanonical(item)); // Recursion
            }
            return item;
        });
        return JSON.stringify(arr);
    }

    const sortedKeys = Object.keys(obj).sort();
    const sortedObj: any = {};

    for (const key of sortedKeys) {
        const val = obj[key];
        if (typeof val === 'object' && val !== null) {
            // Recursive
            // Wait, Dart impl: sorted[key] = jsonDecode(_encodeCanonical(value));
            // It basically re-creates the object sorted.
            // For simple recursion in JS/TS:
            if (Array.isArray(val)) {
                sortedObj[key] = val.map(i => (typeof i === 'object' ? JSON.parse(encodeCanonical(i)) : i));
            } else {
                sortedObj[key] = JSON.parse(encodeCanonical(val));
            }
        } else {
            sortedObj[key] = val;
        }
    }

    return JSON.stringify(sortedObj);
}
