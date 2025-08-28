# Trainerly API Documentation

## Overview

Trainerly provides a comprehensive API for AI-powered fitness applications. This API enables developers to integrate workout generation, health tracking, AI coaching, and social features into their applications.

## Base URL

- **Production**: `https://api.trainerly.eu/v1`
- **Staging**: `https://staging-api.trainerly.eu/v1`
- **Development**: `http://localhost:3000/v1`

## Authentication

All API requests require authentication using Bearer tokens:

```http
Authorization: Bearer <your_access_token>
```

## Rate Limiting

- **Free Tier**: 100 requests/hour
- **Pro Tier**: 1,000 requests/hour
- **Enterprise**: Custom limits

## Error Handling

All errors follow a consistent format:

```json
{
  "error": "ErrorCode",
  "message": "Human readable error message",
  "details": {},
  "timestamp": "2024-01-01T00:00:00Z"
}
```

## Common Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `UNAUTHORIZED` | 401 | Invalid or missing authentication |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource not found |
| `RATE_LIMITED` | 429 | Rate limit exceeded |
| `INTERNAL_ERROR` | 500 | Server error |

## SDKs & Libraries

- [iOS SDK](https://github.com/trainerly/ios-sdk)
- [Android SDK](https://github.com/trainerly/android-sdk)
- [JavaScript SDK](https://github.com/trainerly/js-sdk)
- [Python SDK](https://github.com/trainerly/python-sdk)

## Support

- **Documentation**: [docs.trainerly.eu](https://docs.trainerly.eu)
- **API Status**: [status.trainerly.eu](https://status.trainerly.eu)
- **Support**: [support@trainerly.eu](mailto:support@trainerly.eu)
- **Discord**: [discord.gg/trainerly](https://discord.gg/trainerly)
