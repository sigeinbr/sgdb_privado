#!/bin/sh
set -e

echo "🛠️ Executando Flyway migrate..."
flyway -locations=filesystem:/Scripts -connectRetries=3 migrate

echo "⏸️ Aguardando próximas atualizações..."
tail -f /dev/null
