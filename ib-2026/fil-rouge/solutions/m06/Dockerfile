# Image d'execution FretExpress : installe le paquet wheel produit par le pipeline.
FROM python:3.12-slim
RUN useradd --create-home --uid 10001 app \
 && mkdir -p /app/data && chown app:app /app/data
WORKDIR /app
COPY dist/*.whl /tmp/
RUN pip install --no-cache-dir /tmp/*.whl && rm -f /tmp/*.whl
USER app
ENV FRETEXPRESS_DB=/app/data/fretexpress.db
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"
CMD ["uvicorn", "fretexpress.api:app", "--host", "0.0.0.0", "--port", "8000"]
