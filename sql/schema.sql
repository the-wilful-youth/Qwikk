SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS rides;
DROP TABLE IF EXISTS drivers;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS user_feedback;

SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE users (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100)  NOT NULL,
    mobile        VARCHAR(20)   UNIQUE NOT NULL,
    email         VARCHAR(255)  DEFAULT NULL,
    password_hash VARCHAR(255)  NOT NULL,
    created_at    TIMESTAMP     DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE drivers (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(100) NOT NULL,
    mobile         VARCHAR(20)  UNIQUE NOT NULL,
    vehicle_number VARCHAR(50)  NOT NULL,
    password_hash  VARCHAR(255) DEFAULT NULL,
    vehicle_type   ENUM('bike','scooty','auto','bike-pink','cab-economy','cab-premium') NOT NULL DEFAULT 'bike',
    is_available   BOOLEAN      DEFAULT TRUE,
    created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE rides (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    user_id          INT          NOT NULL,
    driver_id        INT          DEFAULT NULL,
    pickup_location  VARCHAR(255) NOT NULL,
    -- Geolocation for map display and routing
    pickup_lat       DECIMAL(10,7) DEFAULT NULL,
    pickup_lng       DECIMAL(10,7) DEFAULT NULL,
    destination      VARCHAR(255) NOT NULL,
    dropoff_lat      DECIMAL(10,7) DEFAULT NULL,
    dropoff_lng      DECIMAL(10,7) DEFAULT NULL,
    distance_km      DECIMAL(5,2) NOT NULL,
    fare             DECIMAL(8,2) NOT NULL,
    -- bcrypt hash for server-side OTP verification (driver/advance_ride.php)
    otp              VARCHAR(60)  NOT NULL,
    -- Plain 4-digit OTP returned to the passenger's UI so they can read it aloud
    -- to the driver. Short-lived and ride-scoped; acceptable to store unencrypted
    -- because it has zero value once the ride moves past 'driver_arrived'.
    otp_plain        VARCHAR(4)   NOT NULL,
    ride_status      ENUM('waiting','accepted','driver_arrived','started','completed','cancelled') DEFAULT 'waiting',
    payment_status   ENUM('pending','paid') DEFAULT 'pending',
    created_at       TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ride_user   FOREIGN KEY (user_id)   REFERENCES users(id)   ON DELETE CASCADE,
    CONSTRAINT fk_ride_driver FOREIGN KEY (driver_id) REFERENCES drivers(id) ON DELETE SET NULL,
    -- Indexes for the two most common query patterns
    INDEX idx_rides_user_id     (user_id),
    INDEX idx_rides_ride_status (ride_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE payments (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    ride_id        INT          NOT NULL,
    user_id        INT          NOT NULL,
    amount         DECIMAL(8,2) NOT NULL,
    payment_method VARCHAR(50)  NOT NULL,
    paid_at        TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payment_ride FOREIGN KEY (ride_id) REFERENCES rides(id) ON DELETE CASCADE,
    CONSTRAINT fk_payment_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uq_payment_ride (ride_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE user_feedback (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT          NOT NULL,
    ride_id     INT          NOT NULL,
    driver_id   INT          DEFAULT NULL,
    rating      TINYINT      NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comments    TEXT         DEFAULT NULL,
    created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_feedback_user   FOREIGN KEY (user_id)   REFERENCES users(id)   ON DELETE CASCADE,
    CONSTRAINT fk_feedback_ride   FOREIGN KEY (ride_id)   REFERENCES rides(id)   ON DELETE CASCADE,
    CONSTRAINT fk_feedback_driver FOREIGN KEY (driver_id) REFERENCES drivers(id) ON DELETE SET NULL,
    UNIQUE KEY uq_feedback_ride (ride_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
