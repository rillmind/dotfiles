#!/bin/sh

. ~/.scripts/colors.sh

psaq=$(docker ps -aq)
imgaq=$(docker images -aq)
volaq=$(docker volume ls -q)

echo -e "\n${VERDE}>> Limpando docker...${NC}"

if [ -z "$psaq" ]; then
  echo "0 containers Docker!"
else
  docker rm -f $psaq
fi

if [ -z "$imgaq" ]; then
  echo "0 imagens Docker!"
else
  docker rmi -f $imgaq
fi

if [ -z "$volaq" ]; then
  echo "0 volumes do Docker!"
else
  docker volume rm $volaq
fi

docker system prune -a --volumes -f
