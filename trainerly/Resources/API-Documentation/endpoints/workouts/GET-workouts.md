# GET /workouts

Retrieve a list of workouts for the authenticated user.

## Endpoint

```http
GET /api/workouts
```

## Headers

| Header | Type | Required | Description |
|--------|------|----------|-------------|
| `Authorization` | string | Yes | Bearer token for authentication |
| `X-API-Version` | string | No | API version (default: v1) |

## Query Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `page` | integer | No | 1 | Page number for pagination |
| `limit` | integer | No | 20 | Number of workouts per page (max: 100) |
| `type` | string | No | all | Filter by workout type |
| `difficulty` | string | No | all | Filter by difficulty level |
| `duration` | integer | No | all | Filter by duration (minutes) |
| `date_from` | string | No | - | Filter workouts from date (ISO 8601) |
| `date_to` | string | No | - | Filter workouts to date (ISO 8601) |
| `completed` | boolean | No | all | Filter by completion status |

### Workout Types

- `strength` - Strength training workouts
- `cardio` - Cardiovascular workouts
- `yoga` - Yoga and flexibility workouts
- `hiit` - High-intensity interval training
- `pilates` - Pilates workouts
- `mixed` - Mixed workout types

### Difficulty Levels

- `beginner` - Beginner level workouts
- `intermediate` - Intermediate level workouts
- `advanced` - Advanced level workouts
- `athlete` - Athlete level workouts

## Example Request

```bash
curl -X GET "https://api.trainerly.eu/v1/workouts?type=strength&difficulty=intermediate&page=1&limit=10" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json"
```

## Response

### Success Response (200 OK)

```json
{
  "success": true,
  "data": {
    "workouts": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "name": "Upper Body Power",
        "type": "strength",
        "difficulty": "intermediate",
        "duration": 45,
        "estimatedCalories": 320,
        "targetMuscles": ["chest", "shoulders", "triceps"],
        "equipment": ["dumbbells", "bench"],
        "createdAt": "2024-01-01T10:00:00Z",
        "completedAt": "2024-01-01T11:00:00Z",
        "completionRate": 95,
        "aiRating": 4.8,
        "exercises": [
          {
            "id": "ex-001",
            "name": "Bench Press",
            "sets": 4,
            "reps": 8,
            "weight": 60,
            "restTime": 90,
            "formScore": 92
          }
        ]
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 10,
      "total": 45,
      "pages": 5,
      "hasNext": true,
      "hasPrev": false
    }
  }
}
```

### Error Response (401 Unauthorized)

```json
{
  "success": false,
  "error": "UNAUTHORIZED",
  "message": "Invalid or expired access token",
  "timestamp": "2024-01-01T10:00:00Z"
}
```

### Error Response (400 Bad Request)

```json
{
  "success": false,
  "error": "VALIDATION_ERROR",
  "message": "Invalid query parameters",
  "details": {
    "limit": "Limit must be between 1 and 100"
  },
  "timestamp": "2024-01-01T10:00:00Z"
}
```

## Response Fields

### Workout Object

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique workout identifier |
| `name` | string | Workout name |
| `type` | string | Workout type |
| `difficulty` | string | Difficulty level |
| `duration` | integer | Duration in minutes |
| `estimatedCalories` | integer | Estimated calories burned |
| `targetMuscles` | array | Target muscle groups |
| `equipment` | array | Required equipment |
| `createdAt` | string | Creation timestamp (ISO 8601) |
| `completedAt` | string | Completion timestamp (ISO 8601) |
| `completionRate` | integer | Completion percentage (0-100) |
| `aiRating` | float | AI-generated rating (1-5) |
| `exercises` | array | List of exercises |

### Exercise Object

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Exercise identifier |
| `name` | string | Exercise name |
| `sets` | integer | Number of sets |
| `reps` | integer | Number of reps per set |
| `weight` | float | Weight used (kg) |
| `restTime` | integer | Rest time between sets (seconds) |
| `formScore` | integer | Form quality score (0-100) |

### Pagination Object

| Field | Type | Description |
|-------|------|-------------|
| `page` | integer | Current page number |
| `limit` | integer | Items per page |
| `total` | integer | Total number of items |
| `pages` | integer | Total number of pages |
| `hasNext` | boolean | Whether next page exists |
| `hasPrev` | boolean | Whether previous page exists |

## Rate Limiting

This endpoint is subject to rate limiting:

- **Free Tier**: 100 requests/hour
- **Pro Tier**: 1,000 requests/hour
- **Enterprise**: Custom limits

## Notes

- Workouts are returned in reverse chronological order (newest first)
- The `completedAt` field is null for workouts that haven't been completed
- The `aiRating` is generated based on user performance and form quality
- Equipment requirements are suggestions and can be modified by the user
- Target muscles help users understand the focus of each workout

## Related Endpoints

- [POST /workouts](POST-workout.md) - Create a new workout
- [GET /workouts/{id}](GET-workout-by-id.md) - Get workout details
- [PUT /workouts/{id}](PUT-workout.md) - Update workout
- [DELETE /workouts/{id}](DELETE-workout.md) - Delete workout
- [POST /workouts/{id}/start](POST-workout-start.md) - Start workout session
