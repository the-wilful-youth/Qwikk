<?php
declare(strict_types=1);

/**
 * user/cancel_ride.php
 * POST endpoint — cancels a ride for the passenger and frees the assigned driver if any.
 *
 * Required POST field: ride_id
 * Requires active session with user_id set.
 */

require_once __DIR__ . '/../config/bootstrap.php';
header('Content-Type: application/json');

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../models/Ride.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed.']);
    exit;
}

validate_csrf();

if (empty($_SESSION['user_id']) || !is_int($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Unauthorized.']);
    exit;
}

$sessionUserId = $_SESSION['user_id'];

$rawRideId = $_POST['ride_id'] ?? '';
$rideId    = filter_var($rawRideId, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);

if ($rideId === false || $rideId === null) {
    http_response_code(422);
    echo json_encode(['success' => false, 'message' => 'ride_id must be a positive integer.']);
    exit;
}

try {
    $pdo  = Database::getInstance()->getConnection();
    $ride = new Ride($pdo);
    $row  = $ride->getRideById($rideId);
} catch (Throwable) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Could not fetch ride.']);
    exit;
}

if ($row === null) {
    http_response_code(404);
    echo json_encode(['success' => false, 'message' => 'Ride not found.']);
    exit;
}

// Ensure this user owns the ride
if ((int) $row['user_id'] !== $sessionUserId) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Access denied.']);
    exit;
}

// Allow cancellation only if ride is not started, completed or already cancelled
$allowedStatuses = ['waiting', 'accepted', 'driver_arrived'];
if (!in_array($row['ride_status'], $allowedStatuses, true)) {
    http_response_code(422);
    echo json_encode([
        'success' => false,
        'message' => "Cannot cancel a ride with status '{$row['ride_status']}'.",
    ]);
    exit;
}

try {
    $pdo->beginTransaction();

    $ride->updateStatus($rideId, 'cancelled');

    // Free the driver if assigned so they can accept new rides
    if ($row['driver_id'] !== null) {
        $pdo->prepare('UPDATE drivers SET is_available = TRUE WHERE id = :did')
            ->execute([':did' => (int) $row['driver_id']]);
    }

    $pdo->commit();
} catch (Throwable) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Could not cancel ride.']);
    exit;
}

echo json_encode(['success' => true, 'message' => 'Ride successfully cancelled.']);
