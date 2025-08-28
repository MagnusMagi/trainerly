import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const workoutGenerationTime = new Trend('workout_generation_time');
const aiCoachResponseTime = new Trend('ai_coach_response_time');

// Test configuration
export const options = {
  stages: [
    // Warm up
    { duration: '2m', target: 10 },
    // Ramp up to normal load
    { duration: '3m', target: 50 },
    // Stay at normal load
    { duration: '5m', target: 50 },
    // Ramp up to high load
    { duration: '3m', target: 100 },
    // Stay at high load
    { duration: '5m', target: 100 },
    // Ramp up to peak load
    { duration: '3m', target: 200 },
    // Stay at peak load
    { duration: '5m', target: 200 },
    // Ramp down
    { duration: '3m', target: 0 },
  ],
  
  thresholds: {
    // Response time thresholds
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    // Error rate threshold
    http_req_failed: ['rate<0.05'],
    // Custom thresholds
    'workout_generation_time': ['p(95)<800'],
    'ai_coach_response_time': ['p(95)<600'],
    'errors': ['rate<0.05'],
  },
  
  // Test environment variables
  env: {
    BASE_URL: __ENV.BASE_URL || 'https://api.trainerly.eu/v1',
    API_TOKEN: __ENV.API_TOKEN || 'test_token',
    TEST_USER_ID: __ENV.TEST_USER_ID || 'test-user-123',
  },
};

// Test data
const workoutTypes = ['strength', 'cardio', 'yoga', 'hiit', 'pilates', 'mixed'];
const difficulties = ['beginner', 'intermediate', 'advanced', 'athlete'];
const equipment = ['bodyweight', 'dumbbells', 'barbell', 'kettlebell', 'resistance_bands'];
const targetMuscles = ['chest', 'back', 'shoulders', 'biceps', 'triceps', 'abs', 'glutes', 'quads', 'hamstrings', 'calves'];

// Helper functions
function getRandomElement(array) {
  return array[Math.floor(Math.random() * array.length)];
}

function generateRandomWorkoutRequest() {
  return {
    userId: __ENV.TEST_USER_ID || 'test-user-123',
    workoutType: getRandomElement(workoutTypes),
    duration: Math.floor(Math.random() * 105) + 15, // 15-120 minutes
    difficulty: getRandomElement(difficulties),
    equipment: equipment.slice(0, Math.floor(Math.random() * 3) + 1), // 1-3 equipment items
    targetMuscles: targetMuscles.slice(0, Math.floor(Math.random() * 4) + 1), // 1-4 muscle groups
    energyLevel: Math.floor(Math.random() * 10) + 1, // 1-10
    timeOfDay: getRandomElement(['morning', 'afternoon', 'evening', 'night']),
    location: getRandomElement(['gym', 'home', 'outdoor', 'hotel', 'office']),
  };
}

function generateRandomAICoachMessage() {
  const messages = [
    "I'm feeling tired today but want to work out. What should I do?",
    "How can I improve my squat form?",
    "I want to build muscle. What's the best approach?",
    "I'm bored with my current routine. Any suggestions?",
    "How many calories should I eat to lose weight?",
    "What's the best time to work out?",
    "I have a shoulder injury. What exercises should I avoid?",
    "How can I stay motivated to work out regularly?",
    "What's the difference between strength and hypertrophy training?",
    "How long should I rest between sets?",
  ];
  
  return {
    userId: __ENV.TEST_USER_ID || 'test-user-123',
    message: getRandomElement(messages),
    context: {
      mood: getRandomElement(['energetic', 'tired', 'motivated', 'stressed', 'relaxed']),
      energyLevel: Math.floor(Math.random() * 10) + 1,
    },
  };
}

// Main test function
export default function () {
  const baseUrl = __ENV.BASE_URL || 'https://api.trainerly.eu/v1';
  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${__ENV.API_TOKEN || 'test_token'}`,
    'X-API-Version': 'v1',
  };

  // Test 1: AI Workout Generation
  const workoutRequest = generateRandomWorkoutRequest();
  const workoutRes = http.post(
    `${baseUrl}/workouts/generate`,
    JSON.stringify(workoutRequest),
    { headers }
  );

  // Record workout generation time
  workoutGenerationTime.add(workoutRes.timings.duration);

  // Check workout generation response
  const workoutCheck = check(workoutRes, {
    'workout generation status is 200': (r) => r.status === 200,
    'workout generation response time < 800ms': (r) => r.timings.duration < 800,
    'workout generated successfully': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.success && body.data && body.data.workout;
      } catch (e) {
        return false;
      }
    },
    'workout has exercises': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.data?.workout?.exercises?.length > 0;
      } catch (e) {
        return false;
      }
    },
  });

  // Test 2: AI Coach Chat
  const aiCoachRequest = generateRandomAICoachMessage();
  const aiCoachRes = http.post(
    `${baseUrl}/ai/coach`,
    JSON.stringify(aiCoachRequest),
    { headers }
  );

  // Record AI coach response time
  aiCoachResponseTime.add(aiCoachRes.timings.duration);

  // Check AI coach response
  const aiCoachCheck = check(aiCoachRes, {
    'AI coach status is 200': (r) => r.status === 200,
    'AI coach response time < 600ms': (r) => r.timings.duration < 600,
    'AI coach responded successfully': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.success && body.data && body.data.message;
      } catch (e) {
        return false;
      }
    },
    'AI coach provided helpful response': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.data?.message?.length > 20;
      } catch (e) {
        return false;
      }
    },
  });

  // Test 3: Get User Workouts
  const workoutsRes = http.get(
    `${baseUrl}/workouts?page=1&limit=10`,
    { headers }
  );

  // Check workouts response
  const workoutsCheck = check(workoutsRes, {
    'workouts status is 200': (r) => r.status === 200,
    'workouts response time < 300ms': (r) => r.timings.duration < 300,
    'workouts returned successfully': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.success && body.data;
      } catch (e) {
        return false;
      }
    },
  });

  // Test 4: Health Data Sync
  const healthData = {
    userId: __ENV.TEST_USER_ID || 'test-user-123',
    data: {
      steps: Math.floor(Math.random() * 15000) + 1000,
      calories: Math.floor(Math.random() * 800) + 200,
      heartRate: Math.floor(Math.random() * 60) + 60,
      sleepHours: Math.random() * 4 + 6,
      weight: Math.random() * 20 + 60,
      timestamp: new Date().toISOString(),
    },
  };

  const healthRes = http.post(
    `${baseUrl}/health/sync`,
    JSON.stringify(healthData),
    { headers }
  );

  // Check health sync response
  const healthCheck = check(healthRes, {
    'health sync status is 200': (r) => r.status === 200,
    'health sync response time < 400ms': (r) => r.timings.duration < 400,
    'health data synced successfully': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.success && body.data;
      } catch (e) {
        return false;
      }
    },
  });

  // Test 5: Get Challenges
  const challengesRes = http.get(
    `${baseUrl}/challenges`,
    { headers }
  );

  // Check challenges response
  const challengesCheck = check(challengesRes, {
    'challenges status is 200': (r) => r.status === 200,
    'challenges response time < 300ms': (r) => r.timings.duration < 300,
    'challenges returned successfully': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.success && body.data;
      } catch (e) {
        return false;
      }
    },
  });

  // Test 6: Get Leaderboards
  const leaderboardsRes = http.get(
    `${baseUrl}/leaderboards?type=global&timeframe=weekly`,
    { headers }
  );

  // Check leaderboards response
  const leaderboardsCheck = check(leaderboardsRes, {
    'leaderboards status is 200': (r) => r.status === 200,
    'leaderboards response time < 300ms': (r) => r.timings.duration < 300,
    'leaderboards returned successfully': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.success && body.data;
      } catch (e) {
        return false;
      }
    },
  });

  // Record errors
  const allChecks = [workoutCheck, aiCoachCheck, workoutsCheck, healthCheck, challengesCheck, leaderboardsCheck];
  const hasErrors = allChecks.some(check => !check);
  errorRate.add(hasErrors);

  // Think time between requests
  sleep(Math.random() * 3 + 1); // 1-4 seconds
}

// Setup function (runs once before the test)
export function setup() {
  console.log('Starting Trainerly API Load Test');
  console.log(`Base URL: ${__ENV.BASE_URL || 'https://api.trainerly.eu/v1'}`);
  console.log(`Test User ID: ${__ENV.TEST_USER_ID || 'test-user-123'}`);
  
  // Validate environment variables
  if (!__ENV.API_TOKEN) {
    console.warn('Warning: No API token provided. Using test token.');
  }
  
  return {
    baseUrl: __ENV.BASE_URL || 'https://api.trainerly.eu/v1',
    testUserId: __ENV.TEST_USER_ID || 'test-user-123',
  };
}

// Teardown function (runs once after the test)
export function teardown(data) {
  console.log('Trainerly API Load Test completed');
  console.log('Test configuration:', data);
}

// Handle test results
export function handleSummary(data) {
  const summary = {
    'trainerly-load-test-summary.json': JSON.stringify(data, null, 2),
    stdout: `
Trainerly API Load Test Results
===============================

Test Configuration:
- Base URL: ${data.state.testRunDuration ? data.state.testRunDuration : 'N/A'}
- Duration: ${data.metrics.http_req_duration ? `${data.metrics.http_req_duration.values.p95}ms (95th percentile)` : 'N/A'}
- Total Requests: ${data.metrics.http_reqs ? data.metrics.http_reqs.count : 'N/A'}
- Error Rate: ${data.metrics.errors ? `${(data.metrics.errors.rate * 100).toFixed(2)}%` : 'N/A'}

Performance Metrics:
- Workout Generation: ${data.metrics.workout_generation_time ? `${data.metrics.workout_generation_time.values.p95}ms (95th percentile)` : 'N/A'}
- AI Coach Response: ${data.metrics.ai_coach_response_time ? `${data.metrics.ai_coach_response_time.values.p95}ms (95th percentile)` : 'N/A'}
- Overall Response Time: ${data.metrics.http_req_duration ? `${data.metrics.http_req_duration.values.p95}ms (95th percentile)` : 'N/A'}

Threshold Results:
${data.thresholds ? Object.entries(data.thresholds).map(([name, result]) => `- ${name}: ${result.ok ? 'PASS' : 'FAIL'}`).join('\n') : 'N/A'}

Recommendations:
${data.metrics.errors && data.metrics.errors.rate > 0.05 ? '- High error rate detected. Investigate API stability.' : '- Error rate within acceptable limits.'}
${data.metrics.http_req_duration && data.metrics.http_req_duration.values.p95 > 500 ? '- Response time exceeds 500ms threshold. Consider performance optimization.' : '- Response time within acceptable limits.'}
    `,
  };
  
  return summary;
}
