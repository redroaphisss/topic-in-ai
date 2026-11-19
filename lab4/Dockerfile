# Homework 4 RAG application, deployed with the Lab-4 Terraform infrastructure.
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ .
RUN mkdir -p /data
ENV PORT=8080
EXPOSE 8080
CMD ["sh", "-c", "exec uvicorn main:app --host 0.0.0.0 --port \"$PORT\""]
