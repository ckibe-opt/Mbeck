import tensorflow as tf
import os

# 1. Path to the folder you unzipped (where saved_model.pb is)
# We use r"" to handle Windows backslashes correctly
SAVED_MODEL_DIR = r"C:\projects with ai\Projects\Mbeckapp_Final\New folder"
OUTPUT_FILENAME = "efficientnet_lite0_feature_vector.tflite"

print("Starting conversion...")

try:
    # 2. Initialize the converter
    # FIX: Added tags=['train'] because the TF1 variation uses this tag set instead of 'serve'
    converter = tf.lite.TFLiteConverter.from_saved_model(
        SAVED_MODEL_DIR, 
        tags=['train']
    )
    
    # 3. Standard optimizations (keep as float32 for maximum brand accuracy)
    converter.optimizations = []
    
    # 4. Perform conversion
    tflite_model = converter.convert()

    # 5. Save the file
    with open(OUTPUT_FILENAME, "wb") as f:
        f.write(tflite_model)

    print(f"✅ SUCCESS! File created: {OUTPUT_FILENAME}")
    
    # 6. Verify the output shape
    interpreter = tf.lite.Interpreter(model_content=tflite_model)
    interpreter.allocate_tensors()
    output_details = interpreter.get_output_details()
    print(f"📊 Model Output Shape: {output_details[0]['shape']}")
    print("If you see [1, 1280], your model is perfect for brand recognition.")

except Exception as e:
    print(f"❌ Conversion failed: {e}")
    print("\nTip: Ensure the folder contains 'saved_model.pb' and the 'variables' folder.")