CREATE DATABASE test_playground;

-- Switch to the new database
\c test_playground

-- Create the Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create the Orders table (linked to users)
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id) ON DELETE CASCADE,
    product_name VARCHAR(100) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    order_date DATE DEFAULT CURRENT_DATE
);

-- Insert Users
INSERT INTO users (username, email) VALUES
('alice_dev', 'alice@example.com'),
('bob_admin', 'bob@example.com'),
('charlie_qa', 'charlie@example.com');

-- Insert Orders
INSERT INTO orders (user_id, product_name, amount) VALUES
(1, 'Mechanical Keyboard', 120.50),
(1, 'Wireless Mouse', 45.00),
(2, '27-inch Monitor', 299.99),
(3, 'USB-C Hub', 25.00),
(1, 'Webcam Cover', 5.00);

SELECT
    u.username,
    COUNT(o.id) as total_orders,
    SUM(o.amount) as total_spent
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.username
ORDER BY total_spent DESC;

\c defaultdb
DROP DATABASE test_playground;
