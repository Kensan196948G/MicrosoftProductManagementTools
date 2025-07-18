"""
Performance monitor for PyQt6 GUI application.
Monitors memory usage, CPU usage, and rendering performance.
"""

import psutil
import time
import threading
from typing import Dict, List, Optional, Callable
from PyQt6.QtCore import QObject, QTimer, pyqtSignal
from PyQt6.QtWidgets import QWidget, QApplication
import logging


class PerformanceMonitor(QObject):
    """Performance monitoring system for GUI application."""
    
    # Signals for performance updates
    memory_update = pyqtSignal(float, float)  # used_mb, total_mb
    cpu_update = pyqtSignal(float)  # cpu_percentage
    fps_update = pyqtSignal(float)  # frames_per_second
    performance_warning = pyqtSignal(str)  # warning_message
    
    def __init__(self, parent_widget: QWidget):
        super().__init__(parent_widget)
        self.parent_widget = parent_widget
        self.logger = logging.getLogger(__name__)
        
        # Performance metrics
        self.memory_usage_history: List[float] = []
        self.cpu_usage_history: List[float] = []
        self.fps_history: List[float] = []
        self.frame_times: List[float] = []
        
        # Performance thresholds
        self.memory_warning_threshold = 80.0  # 80% of available memory
        self.cpu_warning_threshold = 80.0     # 80% CPU usage
        self.fps_warning_threshold = 30.0     # Below 30 FPS
        
        # Monitoring state
        self.is_monitoring = False
        self.monitoring_interval = 1000  # 1 second
        self.history_size = 60  # Keep 60 data points
        
        # Frame rate monitoring
        self.last_frame_time = time.time()
        self.frame_count = 0
        self.fps_calculation_interval = 1.0  # Calculate FPS every second
        
        # Setup monitoring
        self._setup_monitoring()
        
    def _setup_monitoring(self):
        """Setup performance monitoring timers."""
        # Memory and CPU monitoring timer
        self.system_monitor_timer = QTimer()
        self.system_monitor_timer.timeout.connect(self._update_system_metrics)
        
        # FPS monitoring timer
        self.fps_timer = QTimer()
        self.fps_timer.timeout.connect(self._calculate_fps)
        
        # Performance check timer
        self.performance_check_timer = QTimer()
        self.performance_check_timer.timeout.connect(self._check_performance_warnings)
        
    def start_monitoring(self):
        """Start performance monitoring."""
        if self.is_monitoring:
            return
            
        self.is_monitoring = True
        self.logger.info("Performance monitoring started")
        
        # Start monitoring timers
        self.system_monitor_timer.start(self.monitoring_interval)
        self.fps_timer.start(int(self.fps_calculation_interval * 1000))
        self.performance_check_timer.start(5000)  # Check every 5 seconds
        
        # Reset frame counting
        self.last_frame_time = time.time()
        self.frame_count = 0
        
    def stop_monitoring(self):
        """Stop performance monitoring."""
        if not self.is_monitoring:
            return
            
        self.is_monitoring = False
        self.logger.info("Performance monitoring stopped")
        
        # Stop monitoring timers
        self.system_monitor_timer.stop()
        self.fps_timer.stop()
        self.performance_check_timer.stop()
        
    def _update_system_metrics(self):
        """Update system memory and CPU metrics."""
        try:
            # Get current process
            process = psutil.Process()
            
            # Memory usage
            memory_info = process.memory_info()
            memory_mb = memory_info.rss / (1024 * 1024)  # Convert to MB
            
            # System memory
            system_memory = psutil.virtual_memory()
            total_memory_mb = system_memory.total / (1024 * 1024)
            
            # CPU usage
            cpu_percent = process.cpu_percent()
            
            # Update history
            self._update_history(self.memory_usage_history, memory_mb)
            self._update_history(self.cpu_usage_history, cpu_percent)
            
            # Emit signals
            self.memory_update.emit(memory_mb, total_memory_mb)
            self.cpu_update.emit(cpu_percent)
            
        except Exception as e:
            self.logger.error(f"Error updating system metrics: {e}")
            
    def _update_history(self, history: List[float], value: float):
        """Update performance history with new value."""
        history.append(value)
        if len(history) > self.history_size:
            history.pop(0)
            
    def _calculate_fps(self):
        """Calculate and emit FPS."""
        current_time = time.time()
        time_diff = current_time - self.last_frame_time
        
        if time_diff >= self.fps_calculation_interval:
            fps = self.frame_count / time_diff
            self._update_history(self.fps_history, fps)
            self.fps_update.emit(fps)
            
            # Reset for next calculation
            self.frame_count = 0
            self.last_frame_time = current_time
            
    def _check_performance_warnings(self):
        """Check for performance warnings."""
        warnings = []
        
        # Check memory usage
        if self.memory_usage_history:
            avg_memory = sum(self.memory_usage_history[-5:]) / min(5, len(self.memory_usage_history))
            memory_percent = (avg_memory / (psutil.virtual_memory().total / (1024 * 1024))) * 100
            
            if memory_percent > self.memory_warning_threshold:
                warnings.append(f"High memory usage: {memory_percent:.1f}%")
                
        # Check CPU usage
        if self.cpu_usage_history:
            avg_cpu = sum(self.cpu_usage_history[-5:]) / min(5, len(self.cpu_usage_history))
            
            if avg_cpu > self.cpu_warning_threshold:
                warnings.append(f"High CPU usage: {avg_cpu:.1f}%")
                
        # Check FPS
        if self.fps_history:
            avg_fps = sum(self.fps_history[-5:]) / min(5, len(self.fps_history))
            
            if avg_fps < self.fps_warning_threshold:
                warnings.append(f"Low FPS: {avg_fps:.1f}")
                
        # Emit warnings
        for warning in warnings:
            self.performance_warning.emit(warning)
            
    def record_frame(self):
        """Record a frame for FPS calculation."""
        self.frame_count += 1
        
    def record_frame_time(self, start_time: float):
        """Record frame rendering time."""
        frame_time = time.time() - start_time
        self.frame_times.append(frame_time)
        
        # Keep only recent frame times
        if len(self.frame_times) > 100:
            self.frame_times.pop(0)
            
    def get_performance_stats(self) -> Dict:
        """Get current performance statistics."""
        stats = {
            "memory_usage": 0.0,
            "cpu_usage": 0.0,
            "fps": 0.0,
            "avg_frame_time": 0.0,
            "peak_memory": 0.0,
            "peak_cpu": 0.0,
            "min_fps": 0.0
        }
        
        # Current values
        if self.memory_usage_history:
            stats["memory_usage"] = self.memory_usage_history[-1]
            stats["peak_memory"] = max(self.memory_usage_history)
            
        if self.cpu_usage_history:
            stats["cpu_usage"] = self.cpu_usage_history[-1]
            stats["peak_cpu"] = max(self.cpu_usage_history)
            
        if self.fps_history:
            stats["fps"] = self.fps_history[-1]
            stats["min_fps"] = min(self.fps_history)
            
        if self.frame_times:
            stats["avg_frame_time"] = sum(self.frame_times) / len(self.frame_times)
            
        return stats
        
    def get_performance_report(self) -> str:
        """Get detailed performance report."""
        stats = self.get_performance_stats()
        
        report = "Performance Report\\n"
        report += "=" * 40 + "\\n"
        report += f"Memory Usage: {stats['memory_usage']:.1f} MB\\n"
        report += f"Peak Memory: {stats['peak_memory']:.1f} MB\\n"
        report += f"CPU Usage: {stats['cpu_usage']:.1f}%\\n"
        report += f"Peak CPU: {stats['peak_cpu']:.1f}%\\n"
        report += f"Current FPS: {stats['fps']:.1f}\\n"
        report += f"Minimum FPS: {stats['min_fps']:.1f}\\n"
        report += f"Avg Frame Time: {stats['avg_frame_time']:.3f}s\\n"
        
        # Performance rating
        rating = self._calculate_performance_rating(stats)
        report += f"\\nPerformance Rating: {rating}\\n"
        
        return report
        
    def _calculate_performance_rating(self, stats: Dict) -> str:
        """Calculate overall performance rating."""
        score = 0
        
        # Memory score (lower is better)
        if stats['memory_usage'] < 100:
            score += 25
        elif stats['memory_usage'] < 200:
            score += 20
        elif stats['memory_usage'] < 300:
            score += 15
        elif stats['memory_usage'] < 500:
            score += 10
        else:
            score += 5
            
        # CPU score (lower is better)
        if stats['cpu_usage'] < 20:
            score += 25
        elif stats['cpu_usage'] < 40:
            score += 20
        elif stats['cpu_usage'] < 60:
            score += 15
        elif stats['cpu_usage'] < 80:
            score += 10
        else:
            score += 5
            
        # FPS score (higher is better)
        if stats['fps'] > 60:
            score += 25
        elif stats['fps'] > 45:
            score += 20
        elif stats['fps'] > 30:
            score += 15
        elif stats['fps'] > 15:
            score += 10
        else:
            score += 5
            
        # Frame time score (lower is better)
        if stats['avg_frame_time'] < 0.016:  # ~60 FPS
            score += 25
        elif stats['avg_frame_time'] < 0.033:  # ~30 FPS
            score += 20
        elif stats['avg_frame_time'] < 0.066:  # ~15 FPS
            score += 15
        elif stats['avg_frame_time'] < 0.1:
            score += 10
        else:
            score += 5
            
        # Convert to rating
        if score >= 90:
            return "Excellent"
        elif score >= 80:
            return "Good"
        elif score >= 70:
            return "Fair"
        elif score >= 60:
            return "Poor"
        else:
            return "Critical"
            
    def optimize_performance(self):
        """Apply performance optimizations."""
        self.logger.info("Applying performance optimizations...")
        
        # Reduce update frequency if performance is poor
        stats = self.get_performance_stats()
        
        if stats['cpu_usage'] > 70 or stats['memory_usage'] > 400:
            # Reduce monitoring frequency
            self.monitoring_interval = 2000  # 2 seconds
            self.system_monitor_timer.setInterval(self.monitoring_interval)
            
            # Reduce history size
            self.history_size = 30
            
            self.logger.info("Performance optimization applied: reduced monitoring frequency")
            
    def set_monitoring_interval(self, interval_ms: int):
        """Set monitoring interval in milliseconds."""
        self.monitoring_interval = interval_ms
        if self.is_monitoring:
            self.system_monitor_timer.setInterval(interval_ms)
            
    def set_memory_warning_threshold(self, threshold_percent: float):
        """Set memory warning threshold."""
        self.memory_warning_threshold = threshold_percent
        
    def set_cpu_warning_threshold(self, threshold_percent: float):
        """Set CPU warning threshold."""
        self.cpu_warning_threshold = threshold_percent
        
    def set_fps_warning_threshold(self, threshold_fps: float):
        """Set FPS warning threshold."""
        self.fps_warning_threshold = threshold_fps
        
    def clear_history(self):
        """Clear performance history."""
        self.memory_usage_history.clear()
        self.cpu_usage_history.clear()
        self.fps_history.clear()
        self.frame_times.clear()
        self.logger.info("Performance history cleared")