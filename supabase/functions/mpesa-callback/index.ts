import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.21.0"

serve(async (req) => {
    // 1. Create Supabase Client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(supabaseUrl, supabaseKey);

    try {
        // 2. Parse M-Pesa Callback
        const body = await req.json();
        console.log("M-Pesa Callback:", JSON.stringify(body));

        const stkCallback = body.Body?.stkCallback;
        if (!stkCallback) {
            throw new Error("Invalid M-Pesa Payload");
        }

        const merchantRequestId = stkCallback.MerchantRequestID;
        const checkoutRequestId = stkCallback.CheckoutRequestID;
        const resultCode = stkCallback.ResultCode;
        const resultDesc = stkCallback.ResultDesc;

        // 3. Extract Metadata (Amount, Receipt, Phone, Date)
        let amount = 0.0;
        let mpesaReceiptNumber = null;
        let transactionDate = null;
        let phoneNumber = null;

        if (resultCode === 0 && stkCallback.CallbackMetadata?.Item) {
            const items = stkCallback.CallbackMetadata.Item;
            for (const item of items) {
                if (item.Name === "Amount") amount = item.Value;
                if (item.Name === "MpesaReceiptNumber") mpesaReceiptNumber = item.Value;
                if (item.Name === "TransactionDate") transactionDate = item.Value;
                if (item.Name === "PhoneNumber") phoneNumber = item.Value;
            }
        }

        // 4. Determine Status
        let status = 'failed';
        if (resultCode === 0) status = 'completed';
        else if (resultCode === 1032) status = 'cancelled'; // User cancelled

        // 5. Save/Update Transaction Log
        // We use upsert on checkout_request_id to avoid duplicates
        const { error } = await supabase.from('mpesa_transactions').upsert({
            merchant_request_id: merchantRequestId,
            checkout_request_id: checkoutRequestId,
            result_code: resultCode,
            result_desc: resultDesc,
            amount: amount,
            mpesa_receipt_number: mpesaReceiptNumber,
            transaction_date: transactionDate,
            phone_number: phoneNumber?.toString(),
            status: status,
            raw_response: body,
            // We don't have shop_id or account_reference in callback unfortunately, 
            // unless we saved them as 'pending' previously.
            // But logging the receipt is enough for reconciliation.
        }, { onConflict: 'checkout_request_id' });

        if (error) {
            console.error("DB Insert Error:", error);
        } else {
            console.log(`Transaction ${checkoutRequestId} logged as ${status}`);

            // 6. AUTOMATION: If successful, install module / upgrade subscription
            if (status === 'completed') {
                try {
                    // A. Fetch pending transaction to get context (shop_id, module)
                    // valid pending transaction should have the same checkout_request_id
                    const { data: pending, error: fetchError } = await supabase
                        .from('mpesa_transactions')
                        .select('shop_id, account_reference')
                        .eq('checkout_request_id', checkoutRequestId)
                        .single();

                    if (pending && !fetchError && pending.shop_id) {
                        const shopId = pending.shop_id;
                        const accountRef = pending.account_reference; // e.g. "Module-restaurant" or "Upgrade-ENTERPRISE"

                        console.log(`Processing ${accountRef} for Shop ${shopId}`);

                        if (accountRef && accountRef.startsWith('Module-')) {
                            const moduleId = accountRef.replace('Module-', '');

                            // B. Insert into shop_modules
                            const { error: moduleError } = await supabase
                                .from('shop_modules')
                                .upsert({
                                    shop_id: shopId,
                                    module_id: moduleId,
                                    installed_at: new Date().toISOString(),
                                    module_version: '1.0.0',
                                    is_active: true,
                                }, { onConflict: 'shop_id,module_id' });

                            // C. Update shop's enabled_modules array
                            if (!moduleError) {
                                const { data: shop } = await supabase
                                    .from('shops')
                                    .select('enabled_modules')
                                    .eq('id', shopId)
                                    .single();

                                if (shop) {
                                    const modules = shop.enabled_modules || [];
                                    if (!modules.includes(moduleId)) {
                                        modules.push(moduleId);
                                        await supabase
                                            .from('shops')
                                            .update({ enabled_modules: modules })
                                            .eq('id', shopId);
                                    }
                                }
                                console.log(`✅ Module ${moduleId} installed for shop ${shopId}`);
                            }
                        }
                        // Handle "Upgrade-Tier" logic if needed here (accountRef.startsWith('Upgrade-'))
                    }
                } catch (autoError) {
                    console.error("Automation Error:", autoError);
                }
            }
        }

        // 7. Always return success to Safaricom to acknowledge receipt
        return new Response(JSON.stringify({ result: "success" }), {
            headers: { "Content-Type": "application/json" },
            status: 200,
        });

    } catch (error) {
        console.error("Handler Error:", error.message);
        // Still return 200 so Safaricom doesn't retry endlessly on bad logic
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { "Content-Type": "application/json" },
            status: 200,
        });
    }
})
