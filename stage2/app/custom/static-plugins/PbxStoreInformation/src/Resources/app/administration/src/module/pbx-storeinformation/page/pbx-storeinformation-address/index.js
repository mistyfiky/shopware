import template from './pbx-storeinformation-address.html.twig';
import './pbx-storeinformation-address.scss';

const { Criteria } = Shopware.Data;

Shopware.Component.register('pbx-storeinformation-address', {
    template,
    props: {
        value: {
            type: [Object, Array],
            default: () => [],
        },
        name: {
            type: String,
            default: '',
        },
        disabled: {
            type: Boolean,
        },
    },
    data() {
        return {
            address: this.value ? this.value : {},
        };
    },
    computed: {
        countryRepository() {
            return this.repositoryFactory.create('country');
        },
        country: {
            get() {
                return this.value ? this.value.country : null;
            },

            set(country) {
                this.value.country = country;
            },
        },
        stateCriteria() {
            const criteria = new Criteria();
            if (this.country) {
                criteria.addFilter(Criteria.equals('countryId', this.country));
            }

            return criteria;
        },
    },
    watch: {
        value(value) {
            this.address = value;
        },
    },
    created() {
        if (typeof this.value === 'undefined' || Array.isArray(this.value)) {
            this.$emit('input', {});
        }
    },
});
