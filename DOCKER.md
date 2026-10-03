# MinIO Custom Container Images (GHCR)

Este repositório foi configurado para compilar e disponibilizar imagens Docker do **MinIO Server** diretamente do código-fonte, garantindo autonomia após a descontinuação das imagens públicas no Docker Hub pelo projeto upstream.

---

## 📦 Imagens Disponíveis

As imagens são publicadas no **GitHub Container Registry (GHCR)**:

| Tag | Descrição | Commit Base |
| :--- | :--- | :--- |
| `ghcr.io/lildiop2/minio:RELEASE.2025-04-22T22-12-26Z` | Versão estável utilizada anteriormente no homelab | `0d7408fc` |
| `ghcr.io/lildiop2/minio:RELEASE.2025-10-15T17-29-55Z` | Última release disponível | `9e49d5e7` |
| `ghcr.io/lildiop2/minio:latest` | Aponta para a última release (`RELEASE.2025-10-15T17-29-55Z`) | `9e49d5e7` |

Ambas as imagens incluem:
- Binário do **MinIO Server** compilado estaticamente em Go (`CGO_ENABLED=0`) com metadados de release.
- Utilitário de linha de comando **MinIO Client (`mc`)** em `/usr/bin/mc`.
- Utilitário estático **`curl`** em `/usr/bin/curl`.
- Certificados CA atualizados para TLS/SSL.
- Imagem base minimalista **Red Hat UBI 9 Micro** (`registry.access.redhat.com/ubi9/ubi-micro:latest`).

---

## 🚀 Como Executar no Homelab

### Exemplo 1: Execução com Docker Run

```bash
docker run -d \
  --name minio \
  -p 9000:9000 \
  -p 9001:9001 \
  -e "MINIO_ROOT_USER=minioadmin" \
  -e "MINIO_ROOT_PASSWORD=minioadmin" \
  -v minio_data:/data \
  ghcr.io/lildiop2/minio:RELEASE.2025-04-22T22-12-26Z \
  server /data --console-address ":9001"
```

> **Nota:** Para usar a versão mais recente, basta substituir a tag por `latest` ou `RELEASE.2025-10-15T17-29-55Z`.

---

### Exemplo 2: Docker Compose (`compose.yaml`)

```yaml
services:
  minio:
    image: ghcr.io/lildiop2/minio:RELEASE.2025-04-22T22-12-26Z # ou latest
    container_name: minio
    restart: unless-stopped
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadminpassword
    volumes:
      - minio_data:/data
    command: server /data --console-address ":9001"

volumes:
  minio_data:
```

---

## 🔐 Autenticação no GHCR (GitHub Container Registry)

Por padrão, novos pacotes no GHCR podem ser criados como privados. 

### Para tornar o pacote Público:
1. Acesse o seu GitHub: `https://github.com/users/lildiop2/packages/container/package/minio`
2. Vá em **Package Settings**.
3. Na seção **Danger Zone**, selecione **Change package visibility** e altere para **Public**.
4. Uma vez público, qualquer servidor ou homelab pode fazer `docker pull` sem autenticação.

### Se preferir manter Privado:
No seu servidor do homelab, faça login com um Personal Access Token (PAT) com escopo `read:packages`:
```bash
echo "<SEU_GITHUB_PAT>" | docker login ghcr.io -u lildiop2 --password-stdin
```

---

## 🛠️ Compilação Manual e Scripts Locais

Para compilar localmente na máquina:

```bash
# Compilar ambas as versões:
./build-images.sh --all

# Compilar apenas a versão homelab:
./build-images.sh --homelab

# Compilar apenas a última versão:
./build-images.sh --latest

# Compilar e publicar no GHCR (necessário docker login ghcr.io com permissão write:packages):
./build-images.sh --all --push
```

---

## 🤖 GitHub Actions CI/CD Automático

Um workflow automatizado foi adicionado em [`.github/workflows/docker-publish.yml`](.github/workflows/docker-publish.yml).

- **Automático:** Dispara ao fazer push de tags `RELEASE.*` ou alterações no Dockerfile.
- **Manual (Workflow Dispatch):** Acesse a aba **Actions** no GitHub, selecione **Build and Publish MinIO Images to GHCR**, escolha se deseja compilar `both`, a versão do `homelab` ou a `latest`, e clique em **Run workflow**.
