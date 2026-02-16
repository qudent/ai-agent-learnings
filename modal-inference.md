# Modal Inference Learnings

## 1. Run a 10-line spike first
Before building full inference logic, run a tiny Modal function that imports your core libs and exits.
This catches auth/image/runtime issues early.

## 2. Pin major versions in container images
Fresh resolves can drift and break model loading.
Use explicit major ranges (for example `transformers>=5,<6`) and align with a known-good local stack before large runs.

## 3. Watch for tokenizer-class mismatches
Finetuned checkpoint folders may point to tokenizer classes that fail to resolve in a clean container.
If checkpoint metadata includes `base_model_id`, loading tokenizer from base model is often safer than loading from checkpoint subdir.

## 4. Use checkpoint metadata for robust loading
When checkpoints are saved as raw state dicts, keep a fallback path:
1. Try direct `from_pretrained(checkpoint_dir)`.
2. If it fails, load base model from metadata and then load state dict.

## 5. Modal image build rule: add local files last
`image.add_local_*` should be the final image step unless `copy=True` is used.
Placing build/env steps after local mounts can cause build-time errors.

## 6. Persist model cache in a Modal volume
Mount a volume for HF cache/checkpoints to avoid repeated downloads and reduce startup time/cost.

## 7. Use named secrets for HF auth
Create once with `modal secret create ...` and attach via `modal.Secret.from_name(...)`.
This avoids unauthenticated Hub pulls and improves reliability/rate limits.

## 8. Separate raw token capture from pretty text
For debugging generation behavior, always record:
- generated token IDs
- token strings
- raw decode with special tokens
- cleaned decode without special tokens
- explicit list of generated special-token positions/ids
