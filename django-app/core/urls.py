from django.urls import path
from .views import home, healthz

urlpatterns = [
    path('', home),
    path('healthz', healthz),
]
