# 各模块在 endpoint 中按需 import，避免 Windows multiprocessing 路径问题
# 但模型定义需要在 init_db() 前导入，确保建表
from models.user import User  # noqa: F401
from models.prediction import Prediction  # noqa: F401
from models.report import Report  # noqa: F401
from models.upload import UploadRecord  # noqa: F401
from models.favorite import Favorite  # noqa: F401
from models.monitor import Alert  # noqa: F401
from models.training import TrainingRecord  # noqa: F401
