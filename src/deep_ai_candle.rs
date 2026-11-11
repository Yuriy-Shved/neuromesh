use candle_core::{Device, Tensor, DType};
use candle_transformers::models::bert::{BertModel, Config};
use candle_transformers::quantized_var_builder;
use tokenizers::Tokenizer;
use std::path::Path;

pub struct DeepAuditor {
    model: BertModel,
    tokenizer: Tokenizer,
    device: Device,
}

impl DeepAuditor {
    /// Загрузка квантизованной модели (GGUF Q4_K_M или Q8_0)
    pub fn load(model_dir: &Path, quant: &str) -> anyhow::Result<Self> {
        let device = Device::Cpu;
        
        // Чтение конфигурации архитектуры (config.json)
        let cfg: Config = serde_json::from_str(
            &std::fs::read_to_string(model_dir.join("config.json"))?,
        )?;
        
        // Загрузка весов из GGUF-файла
        let vb = quantized_var_builder::VarBuilder::from_gguf(
            model_dir.join(format!("model-{quant}.gguf")),
            &device,
        )?;
        
        let model = BertModel::load(vb, &cfg)?;
        
        // Загрузка токенизатора
        let tokenizer = Tokenizer::from_file(model_dir.join("tokenizer.json"))
            .map_err(anyhow::Error::msg)?;
            
        Ok(Self { model, tokenizer, device })
    }

    /// Вычисление эмбеддинга (векторного представления) текста
    pub fn embed(&self, text: &str) -> anyhow::Result<Vec<f32>> {
        let encoding = self.tokenizer.encode(text, true).map_err(anyhow::Error::msg)?;
        let ids: Vec<u32> = encoding.get_ids().to_vec();
        let mask: Vec<u32> = encoding.get_attention_mask().to_vec();
        
        // Ограничение длины последовательности (128 токенов хватает для коротких сообщений)
        const SEQ_LEN: usize = 128;
        let mut ids_p = vec![0u32; SEQ_LEN];
        let mut mask_p = vec![0u32; SEQ_LEN];
        
        for (i, (&id, &m)) in ids.iter().zip(&mask).take(SEQ_LEN).enumerate() {
            ids_p[i] = id;
            mask_p[i] = m;
        }

        let input_ids = Tensor::new(ids_p.as_slice(), &self.device)?.reshape((1, SEQ_LEN))?;
        let token_type_ids = Tensor::zeros((1, SEQ_LEN), DType::U32, &self.device)?;
        
        // Прямой проход через модель
        let output = self.model.forward(&input_ids, &token_type_ids, None)?;
        
        // Mean-pooling по токенам (с учетом маски padding'а)
        let mask_tensor = Tensor::new(mask_p.as_slice(), &self.device)?
            .reshape((1, SEQ_LEN, 1))?
            .to_dtype(DType::F32)?;
            
        let summed = (output * mask_tensor)?.sum(1)?;
        let counts = mask_tensor.sum(1)?;
        let mean = summed.broadcast_div(&counts)?;
        
        // L2-нормализация для получения косинусного сходства простым скалярным произведением
        let norm = mean.sqr()?.sum_keepdim(1)?.sqrt()?;
        let normed = mean.broadcast_div(&norm)?;
        
        Ok(normed.flatten_all()?.to_vec1::<f32>()?)
    }

    /// Оценка семантической асимметрии
    pub fn asymmetry(&self, new_msg: &str, original: &str) -> anyhow::Result<f32> {
        let a = self.embed(new_msg)?;
        let b = self.embed(original)?;
        
        // Векторы нормализованы, поэтому dot product = cosine similarity
        let dot: f32 = a.iter().zip(&b).map(|(x, y)| x * y).sum();
        let sim = dot.clamp(-1.0, 1.0);
        
        // Если тема совсем другая (sim < 0.3), это не манипуляция, а другой сюжет
        if sim < 0.3 {
            return Ok(0.0);
        }
        
        // Возвращаем степень асимметрии (1 - сходство)
        Ok((1.0 - sim).clamp(0.0, 1.0))
    }
}