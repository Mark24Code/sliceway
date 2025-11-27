import axios from 'axios';
import { API_BASE_URL } from '../config';

const client = axios.create({
    baseURL: `${API_BASE_URL}/api`,
});

export default client;
