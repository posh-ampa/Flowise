FROM postgres:16-bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl bash tar gzip coreutils cron awscli \
    && rm -rf /var/lib/apt/lists/*


COPY backup-pg.sh /usr/local/bin/backup-pg.sh
COPY backup-files.sh /usr/local/bin/backup-files.sh
COPY run-with-env.sh /usr/local/bin/run-with-env.sh
RUN chmod +x /usr/local/bin/backup-pg.sh /usr/local/bin/backup-files.sh /usr/local/bin/run-with-env.sh

WORKDIR /app

# Default command does nothing; each service will override with a schedule
CMD ["/bin/sh", "-lc", "echo 'No schedule provided'; sleep 3600"]
