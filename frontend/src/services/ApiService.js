import axios from "axios";

const baseURL = import.meta.env.VITE_API_BASE_URL;

const apiUrl = `${baseURL}/api/products`;

export const getProducts = async () => {
  const response = await axios.get(apiUrl);
  return response.data;
}

export const createProduct = async (product) => {
  const response = await axios.post(apiUrl, product);
  return response.data;
}

export const getProductById = async (id) => {
  const response = await axios.get(`${apiUrl}/${id}`);
  return response.data;
}

export const updateProductById = async (id, product) => {
  const response = await axios.put(`${apiUrl}/${id}`, product);
  return response.data;
}

export const deleteProductById = async (id) => {
  const response = await axios.delete(`${apiUrl}/${id}`);
  return response.data;
}