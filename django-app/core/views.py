import random
from django.http import JsonResponse
from django.shortcuts import render

VERSION = "v1.0"   # Change to "v2.0" before building v2 image

def home(request):
    """
    Main endpoint — returns version info as JSON.
    In v2, simulates ~15% error rate for health check / rollback demo (Student 1).
    """
    if VERSION == "v2.0" and random.random() < 0.15:
        return JsonResponse(
            {"error": "Simulated server error in v2"},
            status=500
        )

    return JsonResponse({
        "message": f"Hello from Progressive Delivery Django - {VERSION}",
        "version": VERSION,
        "student_demo": "Traffic shifting / rollback / shadow in action"
    })

def healthz(request):
    """Health check endpoint used by Kubernetes probes and Argo analysis."""
    return JsonResponse({"status": "healthy", "version": VERSION})
