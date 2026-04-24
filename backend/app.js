import express from 'express';

const app = express();
const PORT = Number(process.env.PORT) || 3000;

app.get('/', (req, res) => res.send('Backend is alive'));

app.listen(PORT, '0.0.0.0', () =>
  console.log(`Listening on http://0.0.0.0:${PORT}`)
);
