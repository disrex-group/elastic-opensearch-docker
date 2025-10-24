# Elasticsearch & OpenSearch Docker Images

Automated Docker image builds for Elasticsearch and OpenSearch with pre-installed phonetic and ICU analysis plugins.

## Features

- **Automatic Version Discovery**: Detects new versions from upstream registries daily
- **Smart Building**: Only rebuilds when new versions are available or Dockerfiles change
- **Multi-Architecture**: Supports both `linux/amd64` and `linux/arm64`
- **Pre-installed Plugins**:
  - `analysis-phonetic`
  - `analysis-icu`
- **Flexible Configuration**: Control which versions to build and track

## Quick Start

### Pull Images

```bash
# Elasticsearch
docker pull ghcr.io/OWNER/elasticsearch:8.11
docker pull ghcr.io/OWNER/elasticsearch:7.17

# OpenSearch
docker pull ghcr.io/OWNER/opensearch:2.11
docker pull ghcr.io/OWNER/opensearch:1.3
```

### Use in Docker Compose

```yaml
services:
  elasticsearch:
    image: ghcr.io/OWNER/elasticsearch:8.11
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    ports:
      - "9200:9200"

  opensearch:
    image: ghcr.io/OWNER/opensearch:2.11
    environment:
      - discovery.type=single-node
      - plugins.security.disabled=true
    ports:
      - "9200:9200"
```

## How It Works

### Automated Discovery

The workflows automatically discover available versions from upstream registries:

- **Elasticsearch**: `docker.elastic.co/elasticsearch/elasticsearch`
- **OpenSearch**: `docker.io/opensearchproject/opensearch`

### Version Selection

By default, the system:
1. Discovers all stable releases (excludes alpha, beta, rc, snapshot)
2. Groups versions by major.minor (e.g., 8.11.x → 8.11)
3. Selects only the latest patch for each major.minor
4. Keeps only the last 3 major versions (configurable)
5. Filters based on minimum version thresholds

Example:
- **Elasticsearch**: Builds 8.11.x, 8.10.x, 8.9.x, 7.17.x (keeping majors 8 and 7)
- **OpenSearch**: Builds 2.11.x, 2.10.x, 2.9.x (keeping major 2)

### Build Triggers

Builds are triggered by:
- **Daily schedule**: 6 AM UTC
- **Manual trigger**: Via GitHub Actions workflow_dispatch
- **Code changes**: When Dockerfiles or workflows are modified

### Image Tags

Each build produces multiple tags:
- `major.minor` (e.g., `8.11`) - **Recommended for most use cases**
- `major.minor.patch` (e.g., `8.11.3`) - Specific patch version

## Configuration

### Adjust Version Discovery

Edit `.github/version-config.yml`:

```yaml
# Keep last N major versions
max_major_versions: 3

# Minimum major version to build
elasticsearch_min_major_version: 7
opensearch_min_major_version: 1
```

### Manual Workflow Triggers

You can manually trigger builds with custom options:

1. Go to **Actions** → Select workflow → **Run workflow**
2. Choose build type:
   - **latest-only**: Build only the newest version per major
   - **full**: Build all discovered versions
   - **custom**: Specify versions (supports both formats)
3. Specify custom versions (comma-separated):
   - **Short format**: `2.11,2.10` - Auto-discovers latest patch (e.g., `2.11.0`)
   - **Full format**: `2.11.0,2.10.5` - Uses exact version
   - **Mixed**: `2.11,8.15.3` - Combines both formats
4. Enable **force_rebuild** to rebuild even if images exist

**Example**: Entering `2.11,8.15` will automatically resolve to `2.11.0,8.15.3` (or whatever the latest patches are)

## Available Images

### Elasticsearch

| Registry | Tags |
|----------|------|
| GitHub Container Registry | `ghcr.io/OWNER/elasticsearch:TAG` |
| Docker Hub | `disrex/elasticsearch:TAG` |

### OpenSearch

| Registry | Tags |
|----------|------|
| GitHub Container Registry | `ghcr.io/OWNER/opensearch:TAG` |
| Docker Hub | `disrex/opensearch:TAG` |

## Development

### Local Building

```bash
# Elasticsearch
docker build \
  --build-arg ES_VERSION=8.11.3 \
  -t elasticsearch:8.11 \
  elasticsearch/

# OpenSearch
docker build \
  --build-arg OPENSEARCH_VERSION=2.11.1 \
  -t opensearch:2.11 \
  opensearch/
```

### Testing Version Discovery

The version discovery logic runs in GitHub Actions, but you can test locally:

```bash
# Install crane
brew install crane

# List Elasticsearch versions
crane ls docker.elastic.co/elasticsearch/elasticsearch | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$'

# List OpenSearch versions
crane ls docker.io/opensearchproject/opensearch | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$'
```

## Architecture

### Workflow Overview

```
┌─────────────────────┐
│  Scheduled/Manual   │
│      Trigger        │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Discover Versions  │
│  ─────────────────  │
│  • List upstream    │
│  • Filter stable    │
│  • Group by major   │
│  • Check existing   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   Build Matrix      │
│  ─────────────────  │
│  • 8.11.3 → 8.11    │
│  • 7.17.5 → 7.17    │
│  • (skip existing)  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Parallel Builds    │
│  ─────────────────  │
│  • Multi-platform   │
│  • Push to GHCR     │
│  • Push to Docker   │
└─────────────────────┘
```

### Key Components

1. **Version Discovery Job**: Queries upstream registries and generates build matrix
2. **Build Job**: Builds and pushes images in parallel for each version
3. **Configuration**: `.github/version-config.yml` controls behavior
4. **Crane Tool**: Used for registry operations (listing, manifest checking)

## Troubleshooting

### Builds Not Triggering

- Check if the schedule is active in GitHub Actions settings
- Verify the cron schedule: `0 6 * * *` = 6 AM UTC daily
- Manually trigger via workflow_dispatch

### Version Not Building

- Check if it passes minimum version threshold
- Verify the image doesn't already exist (unless force_rebuild enabled)
- Check workflow logs for discovery output

### Image Availability

- GHCR images require GitHub token authentication
- Docker Hub images are public
- Both registries should have identical content

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes locally
4. Submit a pull request

## License

See LICENSE file for details.

## Credits

Based on patterns from [docker-php-fpm](https://github.com/OWNER/docker-php-fpm) project.
