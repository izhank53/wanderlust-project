FROM node:20-slim AS builder
WORKDIR /app

#it is required to copy package.json first because it contains the list of dependencies and other project configuration like project name , version , scripts , dependencies, metadata
#package-lock.json is a file that contains the exact versions of the dependencies that are installed in the project, it is generated automatically when we run npm install or npm ci
COPY package*.json ./

#Use 'ci' for installing the listed dependencies in package-lock.json
RUN npm ci 

#copy source code to container as it is required to build the project and generate the dist folder which contains the production ready code
COPY . .

#run the build script defined in package.json to generate the dist folder which contains the production ready code, this command will run the build script defined in package.json and it will create a dist folder in the root directory of the project which contains the production ready code
RUN npm run build

FROM nginx:stable-alpine AS runner

RUN apk update && apk upgrade --no-cache

#this is nginx default location for static file, and it will be served on webpage
WORKDIR /usr/share/nginx/html

# Copy only the necessary files from the builder stage to keep the final image small, we only need the dist folder which contains the production ready code, we don't need node_modules or source code in the final image
COPY --from=builder /app/dist /usr/share/nginx/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]