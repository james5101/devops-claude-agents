FROM python:latest

ENV API_KEY=sk-prod-9f8a7b6c5d4e3f2a1b0c
ENV DB_PASSWORD=hunter2-prod
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y curl wget git vim build-essential libpq-dev nginx supervisor net-tools iputils-ping dnsutils
RUN curl -sSL https://example.com/install-cli.sh | sh

ADD . /app

RUN cd /app && pip install -r requirements.txt
RUN pip install flask gunicorn psycopg2-binary requests

RUN cat /app/requirements.txt | grep -v "^#" | wc -l > /app/dep-count.txt

EXPOSE 8000

CMD cd /app && gunicorn -w 4 -b 0.0.0.0:8000 app:app
