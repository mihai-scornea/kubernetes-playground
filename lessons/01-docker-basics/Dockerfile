# Use the official NGINX image from our Nexus registry as the base
FROM k8s-master:8082/nginx:1.25

# Overwrite the default nginx index.html (used printf to properly format the HTML with newlines)
RUN printf '<!DOCTYPE html>\n\
<html>\n\
<head><title>Custom NGINX</title></head>\n\
<body style="background-color:#111;color:#eee;text-align:center;margin-top:50px;">\n\
<h1>Hello from your custom Docker image</h1>\n\
<p>This page was baked into the image!</p>\n\
</body>\n\
</html>' > /usr/share/nginx/html/index.html

# We could modify the Entrypoint (what process this container runs)
# if we wanted, but we will keep the default NGINX entrypoint which starts the web server