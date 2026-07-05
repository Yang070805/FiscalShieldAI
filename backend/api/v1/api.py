"""
API v1 路由汇总
"""

from fastapi import APIRouter

from api.v1.endpoints.auth import router as auth_router
from api.v1.endpoints.predict import router as predict_router
from api.v1.endpoints.report import router as report_router
from api.v1.endpoints.chat import router as chat_router
from api.v1.endpoints.search import router as search_router
from api.v1.endpoints.upload import router as upload_router
from api.v1.endpoints.training import router as training_router
from api.v1.endpoints.monitor import router as monitor_router
from api.v1.endpoints.llm_config import router as llm_config_router
from api.v1.endpoints.data_pipeline import router as data_pipeline_router
from api.v1.endpoints.enterprise import router as enterprise_router

api_router = APIRouter()
api_router.include_router(auth_router)
api_router.include_router(predict_router)
api_router.include_router(report_router)
api_router.include_router(chat_router)
api_router.include_router(search_router)
api_router.include_router(upload_router)
api_router.include_router(training_router)
api_router.include_router(monitor_router)
api_router.include_router(llm_config_router)
api_router.include_router(data_pipeline_router)
api_router.include_router(enterprise_router)
