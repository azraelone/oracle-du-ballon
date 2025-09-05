FROM node:20-alpine

WORKDIR /app

# On est déjà dans le context ./frontend
COPY package.json vite.config.js /app/
RUN npm install

# Puis on copie le reste du code front
COPY . /app

EXPOSE 5173
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "5173"]
