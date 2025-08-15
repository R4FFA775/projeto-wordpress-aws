#!/bin/bash
set -xe

# --- Substitua estas variáveis pelos dados do seu ambiente ---
EFS_ID="aqui-vai-o-id-do-seu-efs"
DB_HOST="aqui-vai-o-endpoint-do-seu-banco-rds"
DB_NAME="aqui-vai-o-nome-do-seu-banco-de-dados"
DB_USER="aqui-vai-o-usuario-do-seu-banco-de-dados"
DB_PASSWORD="aqui-vai-a-senha-do-seu-banco-de-dados"
# -------------------------------------------------------------

# Atualiza o sistema e instala as dependências necessárias
sudo yum update -y
sudo yum install -y amazon-efs-utils docker

# Inicia e habilita o serviço do Docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Instala o Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Cria o ponto de montagem para o EFS e monta o volume
sudo mkdir -p /mnt/efs
sudo mount -t efs -o tls,nfsvers=4.1,_netdev,nofail ${EFS_ID}:/ /mnt/efs

# Garante que o volume EFS seja montado automaticamente após reinicializações
echo "${EFS_ID}:/ /mnt/efs efs _netdev,nfsvers=4.1,tls,nofail 0 0" | sudo tee -a /etc/fstab

# Cria o diretório para os arquivos do WordPress no EFS e ajusta as permissões
sudo mkdir -p /mnt/efs/html
sudo chown -R 33:33 /mnt/efs/html
sudo chmod -R 775 /mnt/efs/html

# Cria o diretório da aplicação e os arquivos de configuração do Docker
mkdir -p /home/ec2-user/wordpress-app
cd /home/ec2-user/wordpress-app

# Cria o arquivo .env com as credenciais do banco de dados
cat <<EOL > .env
WORDPRESS_DB_HOST=${DB_HOST}
WORDPRESS_DB_NAME=${DB_NAME}
WORDPRESS_DB_USER=${DB_USER}
WORDPRESS_DB_PASSWORD=${DB_PASSWORD}
EOL

# Cria o arquivo docker-compose.yaml para definir o serviço do WordPress
cat <<EOF > docker-compose.yaml
services:
  wordpress:
    image: wordpress:latest
    container_name: wordpress-na-aws
    restart: always
    ports:
      - "80:80"
    env_file:
      - .env
    volumes:
      - /mnt/efs/html:/var/www/html
EOF

# Inicia o contêiner do WordPress em segundo plano
sudo /usr/local/bin/docker-compose up -d
