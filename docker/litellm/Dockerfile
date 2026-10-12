ARG FROM_IMAGE=ghcr.io/berriai/litellm:v1.103.3
FROM $FROM_IMAGE

# needed since this is how we stop/start those images during devop (profile selection does not work as expected)
LABEL dw_rag="true"

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=5s --retries=5 --start-period=30s CMD ["python3", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:4000/health/liveliness', timeout=4)"]

LABEL traefik.enable="true"
LABEL traefik.http.services.litellm-backend.loadbalancer.server.scheme="http"
LABEL traefik.http.services.litellm-backend.loadbalancer.server.port="4000"
LABEL traefik.http.routers.litellm-health.priority="30"
LABEL traefik.http.routers.litellm-health.service="litellm-backend"
LABEL traefik.http.routers.litellm-health.tls="true"
LABEL traefik.http.routers.litellm-health.tls.certresolver="letsencrypt"

# this is where we put our generated configuration too
ENV CONFIG_FILE_PATH=/mnt/ragconfig/litellm/config.yaml

COPY bin/litellm-entrypoint.sh /usr/local/bin/litellm-entrypoint.sh
RUN chmod +x /usr/local/bin/litellm-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/litellm-entrypoint.sh"]
CMD ["--port", "4000", "--config", "/mnt/ragconfig/litellm/config.yaml", "--detailed_debug"]
