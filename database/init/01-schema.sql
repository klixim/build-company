-- Database schema for construction company system

DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

CREATE TABLE roles (
    role_id SERIAL PRIMARY KEY,
    name VARCHAR(32) NOT NULL UNIQUE
);

CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(64) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role_id INT NOT NULL REFERENCES roles(role_id) ON DELETE RESTRICT,
    full_name VARCHAR(128) NOT NULL,
    email VARCHAR(128) NOT NULL UNIQUE,
    phone VARCHAR(32),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE clients (
    client_id SERIAL PRIMARY KEY,
    name VARCHAR(128) NOT NULL UNIQUE,
    contact_name VARCHAR(128) NOT NULL,
    email VARCHAR(128) NOT NULL,
    phone VARCHAR(32),
    address TEXT,
    industry VARCHAR(64)
);

CREATE TABLE contractors (
    contractor_id SERIAL PRIMARY KEY,
    name VARCHAR(128) NOT NULL UNIQUE,
    contact_name VARCHAR(128) NOT NULL,
    email VARCHAR(128) NOT NULL,
    phone VARCHAR(32),
    license_number VARCHAR(64) NOT NULL UNIQUE,
    rating SMALLINT CHECK (rating BETWEEN 1 AND 5)
);

CREATE TABLE projects (
    project_id SERIAL PRIMARY KEY,
    name VARCHAR(160) NOT NULL,
    client_id INT NOT NULL REFERENCES clients(client_id) ON DELETE CASCADE,
    contractor_id INT REFERENCES contractors(contractor_id) ON DELETE SET NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    budget NUMERIC(14,2) NOT NULL CHECK (budget >= 0),
    status VARCHAR(32) NOT NULL DEFAULT 'Запланировано',
    description TEXT
);

CREATE TABLE tasks (
    task_id SERIAL PRIMARY KEY,
    project_id INT NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    assigned_to INT REFERENCES users(user_id) ON DELETE SET NULL,
    name VARCHAR(160) NOT NULL,
    due_date DATE, 
    status VARCHAR(32) NOT NULL DEFAULT 'Ожидается',
    priority VARCHAR(16) NOT NULL DEFAULT 'medium',
    estimate_hours NUMERIC(6,2) NOT NULL DEFAULT 0,
    actual_hours NUMERIC(6,2) NOT NULL DEFAULT 0
);

CREATE TABLE materials (
    material_id SERIAL PRIMARY KEY,
    name VARCHAR(128) NOT NULL UNIQUE,
    unit VARCHAR(32) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
    category VARCHAR(64)
);

CREATE TABLE project_materials (
    project_material_id SERIAL PRIMARY KEY,
    project_id INT NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    material_id INT NOT NULL REFERENCES materials(material_id) ON DELETE RESTRICT,
    quantity NUMERIC(10,2) NOT NULL CHECK (quantity >= 0)
);

CREATE TABLE invoices (
    invoice_id SERIAL PRIMARY KEY,
    project_id INT NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE NOT NULL,
    amount NUMERIC(14,2) NOT NULL CHECK (amount >= 0),
    status VARCHAR(32) NOT NULL DEFAULT 'Ожидается'
);

CREATE TABLE audit_log (
    audit_id SERIAL PRIMARY KEY,
    entity VARCHAR(64) NOT NULL,
    action VARCHAR(64) NOT NULL,
    entity_id VARCHAR(64),
    changed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    details TEXT
);

CREATE OR REPLACE FUNCTION invoice_due_check() RETURNS trigger AS $$
BEGIN
    IF NEW.due_date < CURRENT_DATE AND NEW.status = 'Ожидается' THEN
        NEW.status := 'Просрочен';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER invoice_status_trigger
BEFORE INSERT OR UPDATE ON invoices
FOR EACH ROW EXECUTE FUNCTION invoice_due_check();

CREATE OR REPLACE FUNCTION project_status_update() RETURNS trigger AS $$
BEGIN
    IF (SELECT COUNT(*) FROM tasks WHERE project_id = NEW.project_id AND status <> 'Завершено') = 0 THEN
        UPDATE projects SET status = 'Завершено' WHERE project_id = NEW.project_id;
    ELSE
        UPDATE projects SET status = 'В процессе' WHERE project_id = NEW.project_id AND status <> 'К оплате';
    END IF;
    INSERT INTO audit_log(entity, action, entity_id, details)
    VALUES ('project', 'update-status', NEW.project_id::TEXT, 'updated by task status trigger');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER project_status_trigger
AFTER INSERT OR UPDATE ON tasks
FOR EACH ROW EXECUTE FUNCTION project_status_update();

CREATE OR REPLACE FUNCTION project_audit() RETURNS trigger AS $$
DECLARE
    change_action TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        change_action := 'insert';
    ELSIF TG_OP = 'UPDATE' THEN
        change_action := 'update';
    ELSE
        change_action := 'delete';
    END IF;
    INSERT INTO audit_log(entity, action, entity_id, details)
    VALUES ('project', change_action, COALESCE(NEW.project_id::TEXT, OLD.project_id::TEXT), TG_OP || ' on projects');
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER project_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON projects
FOR EACH ROW EXECUTE FUNCTION project_audit();

CREATE OR REPLACE PROCEDURE assign_task(p_task_id INT, p_user_id INT)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE tasks SET assigned_to = p_user_id WHERE task_id = p_task_id;
    INSERT INTO audit_log(entity, action, entity_id, details)
    VALUES ('task', 'assign', p_task_id::TEXT, 'assigned to user ' || p_user_id::TEXT);
END;
$$;

CREATE OR REPLACE PROCEDURE create_invoice(p_project_id INT, p_amount NUMERIC, p_due_date DATE)
LANGUAGE plpgsql
AS $$
DECLARE
    v_invoice_id INT;
BEGIN
    INSERT INTO invoices(project_id, due_date, amount, status)
    VALUES (p_project_id, p_due_date, p_amount, 'Ожидается')
    RETURNING invoice_id INTO v_invoice_id;
    UPDATE projects SET status = 'К оплате' WHERE project_id = p_project_id AND status <> 'Завершено';
    INSERT INTO audit_log(entity, action, entity_id, details)
    VALUES ('invoice', 'create', v_invoice_id::TEXT, 'created with procedure create_invoice');
END;
$$;
