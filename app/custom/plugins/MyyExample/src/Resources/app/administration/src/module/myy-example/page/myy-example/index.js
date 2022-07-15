import template from './myy-example.html.twig';

Shopware.Component.register('myy-example', {
    template,

    mixins: [
        'notification',
    ],

    data() {
        return {
            isLoading: false,
            isSaveSuccessful: false,
        };
    },

    metaInfo() {
        return {
            title: this.$createTitle(),
        };
    },

    methods: {
        saveFinish() {
            this.isSaveSuccessful = false;
        },

        onSave() {
            this.isSaveSuccessful = false;
            this.isLoading = true;

            try {
                this.$refs.systemConfig.saveAll();
                this.isLoading = false;
                this.isSaveSuccessful = true;
            } catch (err) {
                this.isLoading = false;
                this.createNotificationError({
                    message: err,
                });
            }
        },
    },
});
