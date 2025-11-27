import axios from 'axios';

const client = axios.create({
    baseURL: 'http://localhost:4567/api',
});

export default client;
