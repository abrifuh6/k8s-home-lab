# Use an official Nginx image as the base image
FROM nginx:alpine3.19

# Copy the website files into the Nginx document root
COPY index.html /usr/share/nginx/html/index.html
COPY styles.css /usr/share/nginx/html/styles.css

# Expose port 80 to allow external access
EXPOSE 80

# Command to start Nginx when the container runs
CMD ["nginx-debug", "-g", "daemon off;"]

