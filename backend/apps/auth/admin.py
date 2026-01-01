from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.models import User
from .models import Department, UserProfile


class UserProfileInline(admin.StackedInline):
    """Инлайн для профиля пользователя"""
    model = UserProfile
    can_delete = False
    verbose_name_plural = 'Профиль'
    extra = 0
    max_num = 1


class UserAdmin(BaseUserAdmin):
    """Расширенная админка пользователя с профилем"""
    inlines = (UserProfileInline,)
    
    def save_formset(self, request, form, formset, change):
        """Сохраняет формы inline"""
        if formset.model == UserProfile:
            # Для новых пользователей профиль уже создан сигналом, используем get_or_create для безопасности
            if not change and form.instance.pk:
                profile, _ = UserProfile.objects.get_or_create(user=form.instance)
                # Обновляем формы в formset, чтобы они ссылались на существующий профиль
                for form_item in formset.forms:
                    if not form_item.instance.pk or form_item.instance.user_id != form.instance.id:
                        form_item.instance = profile
                        form_item.instance.pk = profile.pk
                        form_item.instance.user = form.instance
        super().save_formset(request, form, formset, change)


@admin.register(Department)
class DepartmentAdmin(admin.ModelAdmin):
    list_display = ['name', 'color', 'description']
    list_filter = ['name']
    search_fields = ['name', 'description']


# Перерегистрируем UserAdmin
admin.site.unregister(User)
admin.site.register(User, UserAdmin)

