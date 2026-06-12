# Machine Learning Models

This directory contains the Core ML face embedding model used by the FaceAuth pipeline.

## MobileFaceNet (InsightFace w600k)

FaceGate uses a pre-trained **MobileFaceNet** model from the [InsightFace](https://github.com/deepinsight/insightface) project. The model was trained on **WebFace600K** (600,000 identities) and produces highly discriminative face embeddings.

| Property | Value |
|----------|-------|
| Architecture | MobileFaceNet |
| Training Data | WebFace600K (600K identities) |
| Input | 112x112 RGB image, normalized to [-1, 1] |
| Output | 512-dimensional L2-normalized embedding vector |
| Model Size | ~6.6 MB (.mlpackage) |
| Inference | ~2-5ms on Apple Neural Engine |
| Format | Core ML (.mlpackage), macOS 13+ |

The model is bundled directly in the app — end users do not need to download or configure anything. `FaceEmbedder` loads it at app startup and routes inference through the Apple Neural Engine for real-time performance.

## How It Works

1. **Face Detection**: Apple Vision framework detects and crops the face from the camera frame.
2. **Preprocessing**: The cropped face is resized to 112x112 and normalized to [-1, 1] range.
3. **Embedding**: MobileFaceNet maps the face image to a 512-dimensional vector on the ANE.
4. **Matching**: Cosine similarity compares the live embedding against enrolled reference embeddings.

## Re-converting the Model

If you need to regenerate the `.mlpackage` from the ONNX source:

```bash
pip install torch coremltools insightface onnxruntime onnx onnx2torch
python3 Scripts/convert_onnx_to_coreml.py
```

## Development Fallback

If the `.mlpackage` is removed from this directory, `FaceEmbedder` falls back to a software-based embedder that generates embeddings from pixel intensity data. This keeps the app functional during development but should not be used for production builds.
