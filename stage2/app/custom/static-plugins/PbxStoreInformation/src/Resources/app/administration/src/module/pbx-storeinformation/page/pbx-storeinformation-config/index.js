import template from './pbx-storeinformation-config.html.twig';

Shopware.Component.register('pbx-storeinformation-config', {
    template,
    mixins: [
        Shopware.Mixin.getByName('notification'),
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

        async onSave() {
            this.isSaveSuccessful = false;
            this.isLoading = true;

            try {
                await this.$refs.systemConfig.saveAll();
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
