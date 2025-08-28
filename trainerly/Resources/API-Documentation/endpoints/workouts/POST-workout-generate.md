# POST /workouts/generate

Generate an AI-powered personalized workout based on user profile and health data.

## Endpoint

```http
POST /api/workouts/generate
```

## Headers

| Header | Type | Required | Description |
|--------|------|----------|-------------|
| `Authorization` | string | Yes | Bearer token for authentication |
| `Content-Type` | string | Yes | application/json |
| `X-API-Version` | string | No | API version (default: v1) |

## Request Body

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `userId` | string | Yes | - | User's unique identifier |
| `workoutType` | string | No | "strength" | Type of workout to generate |
| `duration` | integer | No | 45 | Desired duration in minutes (15-120) |
| `difficulty` | string | No | "auto" | Difficulty level or "auto" for AI determination |
| `equipment` | array | No | [] | Available equipment |
| `targetMuscles` | array | No | [] | Specific muscle groups to target |
| `excludeMuscles` | array | No | [] | Muscle groups to avoid |
| `recentInjuries` | array | No | [] | Recent injuries or limitations |
| `energyLevel` | integer | No | 5 | Current energy level (1-10) |
| `timeOfDay` | string | No | "auto" | Preferred time of day |
| `weather` | string | No | "auto" | Current weather conditions |
| `location` | string | No | "gym" | Workout location (gym, home, outdoor) |

### Workout Types

- `strength` - Strength training with progressive overload
- `cardio` - Cardiovascular endurance training
- `yoga` - Flexibility and mindfulness
- `hiit` - High-intensity interval training
- `pilates` - Core strength and stability
- `mixed` - Combination of multiple types
- `recovery` - Active recovery and mobility

### Difficulty Levels

- `beginner` - Suitable for fitness newcomers
- `intermediate` - For regular exercisers
- `advanced` - For experienced athletes
- `athlete` - Elite level training
- `auto` - AI-determined based on user data

### Equipment Options

- `bodyweight` - No equipment needed
- `dumbbells` - Dumbbells available
- `barbell` - Barbell and plates
- `kettlebell` - Kettlebells available
- `resistance_bands` - Elastic resistance bands
- `bench` - Weight bench
- `pullup_bar` - Pull-up bar
- `cardio_machines` - Treadmill, bike, etc.

### Target Muscles

- `chest` - Pectoral muscles
- `back` - Latissimus dorsi, rhomboids
- `shoulders` - Deltoids
- `biceps` - Biceps brachii
- `triceps` - Triceps brachii
- `abs` - Abdominal muscles
- `glutes` - Gluteal muscles
- `quads` - Quadriceps
- `hamstrings` - Hamstrings
- `calves` - Gastrocnemius, soleus

### Time of Day

- `morning` - Early morning workouts
- `afternoon` - Midday training
- `evening` - Evening sessions
- `night` - Late night workouts
- `auto` - AI-optimized timing

### Location Types

- `gym` - Commercial gym facility
- `home` - Home workout space
- `outdoor` - Outdoor training
- `hotel` - Hotel room workouts
- `office` - Workplace fitness

## Example Request

```json
{
  "userId": "user-12345",
  "workoutType": "strength",
  "duration": 60,
  "difficulty": "intermediate",
  "equipment": ["dumbbells", "bench", "resistance_bands"],
  "targetMuscles": ["chest", "shoulders", "triceps"],
  "excludeMuscles": ["lower_back"],
  "recentInjuries": ["left_shoulder"],
  "energyLevel": 7,
  "timeOfDay": "morning",
  "weather": "sunny",
  "location": "gym"
}
```

## Response

### Success Response (200 OK)

```json
{
  "success": true,
  "data": {
    "workout": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Morning Upper Body Power",
      "type": "strength",
      "difficulty": "intermediate",
      "duration": 60,
      "estimatedCalories": 420,
      "targetMuscles": ["chest", "shoulders", "triceps"],
      "equipment": ["dumbbells", "bench", "resistance_bands"],
      "aiReasoning": "Generated based on your recent chest focus and morning energy patterns",
      "createdAt": "2024-01-01T08:00:00Z",
      "exercises": [
        {
          "id": "ex-001",
          "name": "Dumbbell Bench Press",
          "description": "Lie on bench, press dumbbells up and down",
          "sets": 4,
          "reps": 8,
          "weight": "auto",
          "restTime": 90,
          "formTips": [
            "Keep your back flat on the bench",
            "Lower the weights to chest level",
            "Press up with controlled movement"
          ],
          "videoUrl": "https://trainerly.eu/exercises/bench-press",
          "targetMuscles": ["chest", "triceps", "shoulders"],
          "difficulty": "intermediate",
          "equipment": ["dumbbells", "bench"]
        },
        {
          "id": "ex-002",
          "name": "Dumbbell Shoulder Press",
          "description": "Standing shoulder press with dumbbells",
          "sets": 3,
          "reps": 10,
          "weight": "auto",
          "restTime": 60,
          "formTips": [
            "Keep your core engaged",
            "Press straight up overhead",
            "Avoid arching your back"
          ],
          "videoUrl": "https://trainerly.eu/exercises/shoulder-press",
          "targetMuscles": ["shoulders", "triceps"],
          "difficulty": "intermediate",
          "equipment": ["dumbbells"]
        }
      ],
      "warmup": {
        "duration": 10,
        "exercises": [
          {
            "name": "Arm Circles",
            "duration": 30,
            "description": "Forward and backward arm circles"
          },
          {
            "name": "Light Push-ups",
            "duration": 60,
            "description": "5-10 push-ups to warm up chest"
          }
        ]
      },
      "cooldown": {
        "duration": 5,
        "exercises": [
          {
            "name": "Chest Stretch",
            "duration": 30,
            "description": "Doorway chest stretch"
          },
          {
            "name": "Shoulder Mobility",
            "duration": 30,
            "description": "Shoulder rolls and stretches"
          }
        ]
      },
      "aiInsights": {
        "strength": "Your chest strength has improved 15% this month",
        "recovery": "You're well-rested for this intensity level",
        "progression": "Ready to increase weight on bench press by 2.5kg",
        "motivation": "Morning workouts show 20% better completion rates for you"
      }
    }
  }
}
```

### Error Response (400 Bad Request)

```json
{
  "success": false,
  "error": "VALIDATION_ERROR",
  "message": "Invalid request parameters",
  "details": {
    "duration": "Duration must be between 15 and 120 minutes",
    "difficulty": "Invalid difficulty level"
  },
  "timestamp": "2024-01-01T08:00:00Z"
}
```

### Error Response (404 Not Found)

```json
{
  "success": false,
  "error": "USER_NOT_FOUND",
  "message": "User with ID user-12345 not found",
  "timestamp": "2024-01-01T08:00:00Z"
}
```

### Error Response (422 Unprocessable Entity)

```json
{
  "success": false,
  "error": "INSUFFICIENT_DATA",
  "message": "Not enough health data to generate personalized workout",
  "details": {
    "missingData": ["recent_workouts", "fitness_level", "health_metrics"],
    "suggestion": "Complete your fitness profile or try a generic workout"
  },
  "timestamp": "2024-01-01T08:00:00Z"
}
```

### Error Response (429 Too Many Requests)

```json
{
  "success": false,
  "error": "RATE_LIMIT_EXCEEDED",
  "message": "Too many workout generation requests",
  "details": {
    "limit": "100 requests per hour",
    "resetTime": "2024-01-01T09:00:00Z"
  },
  "timestamp": "2024-01-01T08:00:00Z"
}
```

## Response Fields

### Workout Object

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique workout identifier |
| `name` | string | AI-generated workout name |
| `type` | string | Workout type |
| `difficulty` | string | Difficulty level |
| `duration` | integer | Total duration in minutes |
| `estimatedCalories` | integer | Estimated calories burned |
| `targetMuscles` | array | Primary muscle groups targeted |
| `equipment` | array | Equipment used in workout |
| `aiReasoning` | string | Explanation of workout choices |
| `createdAt` | string | Generation timestamp |
| `exercises` | array | List of exercises |
| `warmup` | object | Warm-up routine |
| `cooldown` | object | Cool-down routine |
| `aiInsights` | object | AI-generated insights |

### Exercise Object

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Exercise identifier |
| `name` | string | Exercise name |
| `description` | string | Exercise description |
| `sets` | integer | Number of sets |
| `reps` | integer | Number of reps per set |
| `weight` | string | Weight to use ("auto" for AI determination) |
| `restTime` | integer | Rest time between sets (seconds) |
| `formTips` | array | Form improvement tips |
| `videoUrl` | string | Instructional video URL |
| `targetMuscles` | array | Muscles worked |
| `difficulty` | string | Exercise difficulty level |
| `equipment` | array | Required equipment |

### Warmup/Cooldown Object

| Field | Type | Description |
|-------|------|-------------|
| `duration` | integer | Duration in minutes |
| `exercises` | array | List of warmup/cooldown exercises |

### AI Insights Object

| Field | Type | Description |
|-------|------|-------------|
| `strength` | string | Strength progress insight |
| `recovery` | string | Recovery status insight |
| `progression` | string | Progression recommendation |
| `motivation` | string | Motivational insight |

## Rate Limiting

This endpoint is subject to stricter rate limiting:

- **Free Tier**: 10 requests/hour
- **Pro Tier**: 100 requests/hour
- **Enterprise**: Custom limits

## AI Features

### Personalization Factors

The AI considers multiple factors when generating workouts:

1. **User Profile**
   - Fitness level and experience
   - Goals and preferences
   - Available equipment
   - Time constraints

2. **Health Data**
   - Recent workout performance
   - Recovery status
   - Injury history
   - Energy levels

3. **Behavioral Patterns**
   - Preferred workout times
   - Completion rates
   - Exercise preferences
   - Progress patterns

4. **Environmental Factors**
   - Weather conditions
   - Available space
   - Equipment availability
   - Time of day

### Progressive Overload

The AI automatically adjusts workout difficulty based on:

- Recent performance improvements
- Workout completion rates
- Form quality scores
- User feedback ratings

### Injury Prevention

The AI considers injury prevention by:

- Avoiding recently injured muscle groups
- Suggesting appropriate warm-up routines
- Monitoring exercise variety
- Adjusting intensity based on recovery

## Notes

- Generated workouts are cached for 24 hours to avoid excessive API calls
- The AI learns from user feedback and workout completion data
- Workouts can be modified by users after generation
- Equipment suggestions are flexible and can be substituted
- The AI adapts to user preferences over time

## Related Endpoints

- [POST /workouts](POST-workout.md) - Create custom workout
- [PUT /workouts/{id}](PUT-workout.md) - Modify generated workout
- [POST /workouts/{id}/start](POST-workout-start.md) - Start workout session
- [POST /workouts/{id}/feedback](POST-workout-feedback.md) - Provide workout feedback
- [GET /workouts/recommendations](GET-workout-recommendations.md) - Get workout recommendations
