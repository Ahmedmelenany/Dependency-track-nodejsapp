const express = require('express');
const axios = require('axios');
const jwt = require('jsonwebtoken');
const _ = require('lodash');

const app = express();
app.use(express.json());

app.get('/', (req, res) => {
  res.json({ message: 'my-app is running', version: '1.0.0' });
});

app.get('/users', (req, res) => {
  const users = [
    { id: 1, name: 'Alice', role: 'admin' },
    { id: 2, name: 'Bob', role: 'user' },
  ];
  res.json(_.sortBy(users, 'name'));
});

app.post('/login', (req, res) => {
  const { username } = req.body;
  const token = jwt.sign({ username }, 'secret', { expiresIn: '1h' });
  res.json({ token });
});

const PORT = 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
