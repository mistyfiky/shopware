import './page/pbx-storeinformation-config';
import './page/pbx-storeinformation-address';

Shopware.Module.register('pbx-storeinformation', {
    type: 'plugin',
    name: 'plugin',
    title: 'pbx-storeinformation.general.mainMenuItemGeneral',
    description: 'pbx-storeinformation.general.descriptionTextModule',
    color: '#9aa8b5',
    icon: 'default-badge-info',

    routes: {
        config: {
            component: 'pbx-storeinformation-config',
            path: 'config',
            meta: {
                parentPath: 'sw.settings.index',
                privilege: 'system.system_config',
            },
        },
    },
    settingsItem: {
        group: 'shop',
        position: 3,
        to: 'pbx.storeinformation.config',
        icon: 'default-badge-info',
    },
});
