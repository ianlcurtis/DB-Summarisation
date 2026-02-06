# Build stage
FROM node:20-alpine AS build

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage - serve with nginx
FROM nginx:alpine AS production

# Copy custom nginx config template
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

# Copy built assets from build stage
COPY --from=build /app/dist /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# nginx will automatically substitute environment variables in templates
# The API_URL env var will be used to configure the proxy
ENV API_URL=http://localhost:5200

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
