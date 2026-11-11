# Модель MiniLM Q4_K_M (~22 MB)

Скачивается из IPFS по CID из /neuromesh/model-manifest/current.

    ipfs get <CID> -o minilm-q4_k_m.gguf
    sha256sum minilm-q4_k_m.gguf

Конвертация из оригинальной модели:
    cargo install --git https://github.com/huggingface/candle.git candle-quantized
    candle-quantized quantize \
        --model sentence-transformers/all-MiniLM-L6-v2 \
        --quant q4_k_m --output-dir ./models
