import './page/myy-example';
import enGB from './snippet/en-GB';

Shopware.Module.register('myy-example', {
    type: 'plugin',
    name: 'MyyExample',
    title: 'myy-example.general.mainMenuItemGeneral',
    description: 'myy-example.general.descriptionTextModule',
    color: '#ff3d58',
    icon: 'default-action-settings',

    snippets: {
        'en-GB': enGB,
    },

    routes: {
        index: {
            component: 'myy-example',
            path: 'index',
        },
    },

    settingsItem: {
        group: 'plugins',
        to: 'myy.example.index',
        icon: 'default-action-settings',
    },
});
