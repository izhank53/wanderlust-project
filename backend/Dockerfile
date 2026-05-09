# --- Stage 1: The Builder ---

FROM node:20-slim AS builder

WORKDIR /app

COPY package*.json ./

#Use 'ci' for exact versions and 'omit=dev' to keep it lean
RUN npm ci --omit=dev

COPY . .

FROM node:20-alpine AS runner

RUN apk update && apk upgrade --no-cache

WORKDIR /app

# Create a non-root user to run the application securely
RUN addgroup -S nodegroup && adduser -S salman -G nodegroup

# Copy only the necessary files from the builder stage to keep the final image small

#node_modules is a package that contains all the dependencies of the project
#when we run npm ci it download 1000 of small folder/dependency like nodeman , jest or compilers which are not required for  prod env
#COPY --from=builder /app/node_modules ./node_modules  
COPY --from=builder /app .

#this tells node.js that this app is running in production mode, it will help to optimize the performance of the app and it will also disable some development features that are not needed in production
ENV NODE_ENV=production

USER salman

EXPOSE 5000
 
CMD ["node", "server.js"]