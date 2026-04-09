# GradeGuess Terraform

S3 + CloudFront infrastructure for the GradeGuess game site.

## What this creates

- **S3 bucket** — Stores static site files and card images under `/cards/`
- **CloudFront distribution** — HTTPS CDN with SPA fallback (403 → index.html)
- **S3 lifecycle rule** — Expires card images under `/cards/` after 90 days
- **Ordered cache behavior** — `/cards/*` cached for up to 7 days; everything else up to 24 hours

## Deploy

```bash
terraform init
terraform plan
terraform apply
```

Note the CloudFront URL from outputs.

## Post-apply

1. **Update Hikokyu Lambda env vars** (in `../hikokyu/`):
   - `ALLOWED_ORIGIN` — add the GradeGuess CloudFront URL
   - `IMAGE_BUCKET` — the S3 bucket name (e.g. `gradeguess-site`)
   - `IMAGE_CDN_URL` — the CloudFront URL (e.g. `https://dxxxxxx.cloudfront.net`)

2. **Deploy the frontend**:
   ```bash
   cd ../../gradeguess && npm run build
   aws s3 sync dist/ s3://gradeguess-site/
   aws cloudfront create-invalidation --distribution-id <DISTRIBUTION_ID> --paths "/*"
   ```
