# Benchmarking

## System Integration Diagram

![drawio.svg](drawio.svg)

### What is NIM?

**NVIDIA Inference Microservices (NIM)** is a containerized inference solution optimized for running LLMs on NVIDIA GPUs. It provides:
- Pre-optimized model serving with vLLM or TensorRT-LLM backend
- Multi-GPU support with tensor parallelism
- OpenAI-compatible API endpoints
- Automatic model downloading and caching from NGC (NVIDIA GPU Cloud)
- Supports various precision formats (fp32, fp16, bfloat16)

### NGC Inference Server & Container Images

**NGC (NVIDIA GPU Cloud)** is NVIDIA's repository for GPU-optimized containers. NIM images from NGC include:
- Pre-configured vLLM or TensorRT-LLM engines
- Model downloader and optimizer
- Health check endpoints
- Support for model quantization and optimization profiles
- Format: `nvcr.io/nim/[vendor]/[model]:[version]`

When you pull a NIM image, it contains the inference engine but not the actual model weights. The model downloads on first run based on the selected profile.

### GenAI-Perf Tool

**GenAI-Perf** is NVIDIA's benchmarking tool for measuring LLM inference performance. Key features:
- **Modes**: profile (steady-state), concurrency sweeps, input/output token sweeps
- **Metrics tracked**: Time-To-First-Token (TTFT), inter-token latency, end-to-end latency, throughput
- **Synthetic requests**: Generate consistent test loads with configurable token lengths
- **Streaming support**: Support for Streaming APIs
- **Report generation**: Produces detailed performance reports and visualizations

### Output Metrics

Important metrics GenAI-Perf collects:

| Metric | Meaning | Target Use |
|--------|---------|-----------|
| **Time To First Token (TTFT)** | Latency from request to first token | User-facing responsiveness |
| **Inter-Token Latency** | Time between subsequent tokens | Streaming quality perception |
| **Request Latency** | Total time from request to completion | Batch processing efficiency |
| **Throughput** | Tokens generated per second | Model capacity |

### Model Size & Memory Requirements

Rule of thumb for model memory requirements:
- **Example**: 7B parameter model (float16) = ~14GB weights, needs ~35GB total GPU memory
- Larger context windows require more KV cache memory
- Batch size multiplies memory requirements

### Precision & Model Size

Precision affects both model size and speed:

**Why it matters:**
- **Memory**: Lower precision = fewer bytes per weight = smaller model footprint in VRAM
- **Speed**: GPUs have specialized hardware (Tensor Cores) optimized for lower precision math operations
- **Bandwidth**: Less data movement between GPU memory and compute units = higher throughput
- **Trade-off**: Lower precision can introduce small accuracy degradation, but modern formats (bf16, fp8, nvfp4) minimize this

| Precision | Bytes per Parameter | Speed | Use Case |
|-----------|-------------------|-------|----------|
| float32 (fp32) | 4 bytes | Baseline | Reference/high precision |
| float16 (fp16) | 2 bytes | 2-4x faster | Standard production |
| bfloat16 (bf16) | 2 bytes | Similar to fp16 | Better numerical stability |
| float8 (fp8) | 1 byte | 4-8x faster | NVIDIA H100+ tensor cores |
| int8 | 1 byte | 4-8x faster | Quantized, slight accuracy loss |
| int4 | 0.5 bytes | 8-16x faster | Aggressive quantization |
| **NVFP4** | 0.5 bytes | 8-16x faster | NVIDIA 4-bit floating point, Ada/Hopper |

**NVIDIA-Specific Formats:**
- **FP8 (E4M3, E5M2)**: Native support on H100+ GPUs, balance between range and precision
- **NVFP4**: Custom 4-bit floating point format optimized for transformer models on Ada Lovelace/Hopper architectures
- **TensorFloat-32 (TF32)**: Automatic on A100/H100 for fp32 operations (19-bit precision, 8-bit exponent)

### NVIDIA Profiles

**Profiles** are optimized configurations for a specific model. Available profiles vary by model and include:
- Different tensor parallelism strategies (TP1, TP2, TP4)
- Different precision formats (float16, bfloat16)
- Different serving engines (vLLM, TensorRT-LLM)
- Example profile: `cc2e0f9cb33ad6f9d31f64c0c1188342b00f427569a62a46397dfa33a2db7695` = vLLM with bfloat16, tensor parallel 1

Query available profiles for your model before deploying.

## Token Examples

Typical input/output token counts for common tasks:

| Task | Input Tokens | Output Tokens | Notes |
|------|--------------|---------------|-------|
| Translation | 150-300 | 150-300 | Varies by language complexity |
| Summarization | 500-2000 | 100-300 | Depends on source length |
| Question Answering | 200-500 | 50-200 | Context + question |
| Code Generation | 100-500 | 200-1000 | Problem description + solution |
| Essay Writing | 50-200 | 500-2000 | Prompt + long-form output |
| Chat Response | 50-150 | 100-500 | Single conversation turn |
| Classification | 100-500 | 10-50 | Text + category output |
| Information Extraction | 300-1000 | 100-500 | Document + structured data |

## Prerequisites

- ngc api key
- huggingface api key

### Flow Summary

1. **Pull Image**: Download optimized NIM container from NGC registry
2. **Start Container**: Run NIM with GPU support and model profile
3. **Load Model**: NIM downloads and caches model on first run
4. **Serve API**: NIM exposes OpenAI-compatible endpoints
5. **Generate Load**: GenAI-Perf sends synthetic requests with configurable tokens
6. **Process**: NIM processes on GPU(s) with selected precision/profile
7. **Measure**: GenAI-Perf collects latency and throughput metrics
8. **Report**: Results exported as JSON/CSV for analysis

## genai-perf


### docker login

```
export NGC_API_KEY=API_KEY
echo $NGC_API_KEY | docker login nvcr.io -u \$oauthtoken --password-stdin
```

## Search for the right profile

```bash
export IMG_NAME=nvcr.io/nim/microsoft/phi-3-mini-4k-instruct:1.2.3
docker run --rm --gpus=all -e NGC_API_KEY=$NGC_API_KEY $IMG_NAME list-model-profiles
```

## Run the inference server

```bash
# cc2e0f9cb33ad6f9d31f64c0c1188342b00f427569a62a46397dfa33a2db7695 (vllm-bf16-tp1)
export NIM_MODEL_PROFILE=cc2e0f9cb33ad6f9d31f64c0c1188342b00f427569a62a46397dfa33a2db7695

# Ensure cache directory has proper permissions
mkdir -p nim-cache
chmod -R 777 nim-cache

docker run -d \
  --name inference-server \
  --restart unless-stopped \
  -p 8000:8000 \
  -v $(pwd)/nim-cache:/opt/nim/.cache \
  -e NIM_CACHE_PATH=/opt/nim/.cache \
  -e NGC_API_KEY=${NGC_API_KEY} \
  -e NIM_MODEL_PROFILE=${NIM_MODEL_PROFILE} \
  --shm-size=4gb \
  --gpus all \
  ${IMG_NAME}

# Check if server is ready (may take several minutes to load the model)
curl -f http://localhost:8000/v1/health/ready | jq

# Watch logs while model loads
docker logs -f inference-server
```

### starth the benchmark

```
export MODEL=$(curl -s http://localhost:8000/v1/models | jq -r '.data[0].id')
echo $MODEL
docker run -it --rm --net=host \
  -v /tmp:/tmp \
  nvcr.io/nvidia/tritonserver:25.12-py3-sdk \
  genai-perf profile \
    --endpoint-type chat \
    --url http://localhost:8000 \
    --model $MODEL \
    --concurrency 10 \
    --warmup-request-count 10 \
    --request-count 50 \
    --synthetic-input-tokens-mean 200 \
    --synthetic-input-tokens-stddev 0 \
    --output-tokens-mean 100 \
    --output-tokens-stddev 0 \
    --artifact-dir /tmp/genai-perf \
    --streaming \
    -v
```

Tune the benchmark by changing input/output tokens
```bash
    --synthetic-input-tokens-mean 200 \
    --synthetic-input-tokens-stddev 0 \
    --output-tokens-mean 100 \
    --output-tokens-stddev 0 \
```

### results format

```
                                     NVIDIA GenAI-Perf | LLM Metrics
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┓
┃                            Statistic ┃      avg ┃      min ┃      max ┃      p99 ┃      p90 ┃      p75 ┃
┡━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━┩
│             Time To First Token (ms) │   188.31 │    67.28 │   261.97 │   261.96 │   261.49 │   233.43 │
│            Time To Second Token (ms) │    42.30 │    30.05 │   180.03 │   180.03 │    31.20 │    30.38 │
│                 Request Latency (ms) │ 3,191.04 │ 1,990.72 │ 3,305.49 │ 3,305.03 │ 3,304.50 │ 3,287.56 │
│             Inter Token Latency (ms) │    30.69 │    29.36 │    32.60 │    32.49 │    31.86 │    30.94 │
│     Output Token Throughput Per User │    32.60 │    30.68 │    34.06 │    34.06 │    34.06 │    33.14 │
│                    (tokens/sec/user) │          │          │          │          │          │          │
│      Output Sequence Length (tokens) │    98.84 │    60.00 │   101.00 │   101.00 │   101.00 │   101.00 │
│       Input Sequence Length (tokens) │   200.12 │   200.00 │   201.00 │   201.00 │   201.00 │   200.00 │
│ Output Token Throughput (tokens/sec) │   303.66 │      N/A │      N/A │      N/A │      N/A │      N/A │
│         Request Throughput (per sec) │     3.07 │      N/A │      N/A │      N/A │      N/A │      N/A │
│                Request Count (count) │    50.00 │      N/A │      N/A │      N/A │      N/A │      N/A │
└──────────────────────────────────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
```

## References

- [https://docs.nvidia.com/nim/large-language-models/latest/benchmarking.html](https://docs.nvidia.com/nim/large-language-models/latest/benchmarking.html)
- [https://docs.nvidia.com/deeplearning/triton-inference-server/user-guide/docs/perf_benchmark/genai_perf.html](https://docs.nvidia.com/deeplearning/triton-inference-server/user-guide/docs/perf_benchmark/genai_perf.html)
