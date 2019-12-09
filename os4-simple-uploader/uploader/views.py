import os

from django.conf import settings
from django.http import HttpResponse, HttpResponseNotFound
from django.views.decorators.csrf import csrf_exempt
from django.core.files.storage import default_storage


def handle_uploaded_file(path, f):
    if 'file' not in f:
        return
    if path.startswith("/") or '..' in path:
        return

    save_path = os.path.join(settings.MEDIA_ROOT, 'fileuploads', path)
    # Security breach?
    if not os.path.abspath(save_path).startswith(settings.MEDIA_ROOT):
        return
    if os.path.exists(save_path):
        os.path.remove(save_path)
    if not os.path.exists(os.path.dirname(save_path)):
        os.makedirs(os.path.dirname(save_path))
    default_storage.save(save_path, f['file'])
    return


@csrf_exempt
def index(request):
    if request.method == 'POST':
        handle_uploaded_file(request.POST['path'], request.FILES)

    return HttpResponse("OS4 Install!!!")


def show(request, path):
    if path.startswith("/") or '..' in path:
        return HttpResponse("denied")
    fullpath = os.path.join(settings.MEDIA_ROOT, 'fileuploads', path)
    if not os.path.abspath(fullpath).startswith(settings.MEDIA_ROOT):
        return
    if not os.path.exists(fullpath) and not os.path.isfile(fullpath):
        return HttpResponseNotFound("Page %s not found" % path)

    return HttpResponse(default_storage.open(fullpath).read())


# Create your views here.
