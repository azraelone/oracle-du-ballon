FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libpq-dev ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# On est dans le context ./etl => on copie requirements.txt depuis ce context
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Puis on copie tout le code ETL du context courant vers /app
COPY . /app

# Le package "etl" est dans /app/etl ; on peut lancer "python -m etl.run"
CMD ["python", "-m", "etl.run"]
