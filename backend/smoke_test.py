import requests
import time
import subprocess
import os

def smoke_test():
    print("Starting Backend Smoke Test...")
    
    env = os.environ.copy()
    env["SUPABASE_URL"] = "https://example.supabase.co"
    env["SUPABASE_ANON_KEY"] = "dummy"
    env["SUPABASE_SERVICE_ROLE_KEY"] = "dummy"
    env["GEMINI_API_KEY"] = "dummy"
    env["PORT"] = "8081"

    # Ensure PYTHONPATH is set so app can find .config/etc
    env["PYTHONPATH"] = "."

    process = subprocess.Popen(
        ["python", "-m", "app.main"],
        cwd="a:/Personal projects/Zdorovya/backend",
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    print("Waiting for server to start...")
    time.sleep(7)

    try:
        response = requests.get("http://localhost:8081/health", timeout=5)
        if response.status_code == 200:
            print("Backend is ALIVE and healthy!")
        else:
            print(f"Backend returned status {response.status_code}")
    except Exception as e:
        print(f"Failed to connect to Backend: {e}")
        # Check if process crashed
        stdout, stderr = process.communicate(timeout=1)
        print(f"Process stdout: {stdout}")
        print(f"Process stderr: {stderr}")
    finally:
        process.terminate()
        print("Backend stopped.")

if __name__ == "__main__":
    smoke_test()
