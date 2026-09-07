package com.example.backend.service.impl;

import com.example.backend.model.Product;
import com.example.backend.repository.ProductRepository;
import com.example.backend.service.ProductService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@Service
public class ProductServiceImpl implements ProductService {

    @Autowired
    private ProductRepository productRepository;

    @Override
    public Product save(Product product) {
        return productRepository.save(product);
    }

    @Override
    public Product updateById(Long id, Product product) {

        Product managedProduct = this.findById(id);
        managedProduct.setTitle(product.getTitle());
        managedProduct.setQuantity(product.getQuantity());
        managedProduct.setPrice(product.getPrice());

        return this.save(managedProduct);
    }

    @Override
    public List<Product> findAll() {
        return productRepository.findAll();
    }

    @Override
    public Product findById(Long id) {
        return productRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Product " + id + " not found"));
    }

    @Override
    public void deleteById(Long id) {
        if (!productRepository.existsById(id)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Product " + id + " not found");
        }
        productRepository.deleteById(id);
    }

}
