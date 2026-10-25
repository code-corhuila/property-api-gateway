FROM nginx:1.27-alpine
# The image's own example server is not part of the gateway.
RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/conf.d/ /etc/nginx/conf.d/
COPY nginx/snippets/ /etc/nginx/snippets/
COPY nginx/routes/ /etc/nginx/routes/
# Written into /etc/nginx/conf.d/ at start-up, with only the variables named CORS_*.
COPY nginx/templates/ /etc/nginx/templates/
ENV NGINX_ENVSUBST_FILTER=^CORS_ \
    CORS_ALLOWED_ORIGIN=http://localhost:4200
EXPOSE 8080
