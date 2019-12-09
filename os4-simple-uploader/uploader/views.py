import os

from django.conf import settings
from django.http import HttpResponse
from django.views.decorators.csrf import csrf_exempt
from django.core.files.storage import default_storage
from django.core.exceptions import PermissionDenied
from django.core.exceptions import SuspiciousOperation


def handle_uploaded_file(path, f):
    if 'file' not in f:
        raise SuspiciousOperation('Invalid upload with no file form data')

    if not path:
        raise SuspiciousOperation('Invalid upload with no path destination')

    save_path = os.path.join(settings.MEDIA_ROOT, path)
    # Security breach?
    if not os.path.abspath(save_path).startswith(
            settings.MEDIA_ROOT) or path.startswith("/") or '..' in path:
        raise PermissionDenied("You are not allowed to upload like this")
    if default_storage.exists(save_path):
        default_storage.delete(save_path)
    default_storage.save(save_path, f['file'])
    return


@csrf_exempt
def upload(request):
    if request.method == 'POST':
        handle_uploaded_file(request.POST['path'], request.FILES)
    return HttpResponse("OK")


def index(request):
    return HttpResponse("OS4 Install!!!")


# Create your views here.
