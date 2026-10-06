-- Sample data for backup/restore testing
CREATE TABLE IF NOT EXISTS orders (
    id         SERIAL PRIMARY KEY,
    customer   VARCHAR(100),
    product    VARCHAR(100),
    amount     NUMERIC(10,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO orders (customer, product, amount) VALUES
    ('Alice',   'Laptop',   1200.00),
    ('Bob',     'Phone',     800.00),
    ('Charlie', 'Tablet',    400.00),
    ('Dave',    'Monitor',   350.00),
    ('Eve',     'Keyboard',   50.00);

CREATE TABLE IF NOT EXISTS users (
    id         SERIAL PRIMARY KEY,
    name       VARCHAR(100),
    email      VARCHAR(100) UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO users (name, email) VALUES
    ('Alice',   'alice@example.com'),
    ('Bob',     'bob@example.com'),
    ('Charlie', 'charlie@example.com');
