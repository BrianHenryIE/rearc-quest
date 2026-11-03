FROM node:10

WORKDIR /app

# Must run build from directory containing rearc-quest: `docker build . -f ./3-container/Dockerfile -t "rearc-quest"`.
COPY rearc-quest .

RUN ["npm", "install"]

CMD ["npm", "start"]

# docker run -p 3000:3000 rearc-quest:latest
# curl localhost:3000/docker