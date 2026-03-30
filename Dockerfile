FROM nginx:1.25-alpine

LABEL maintainer="david.vidosic16@gmail.com"

RUN rm -rf /usr/share/nginx/html/*

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
