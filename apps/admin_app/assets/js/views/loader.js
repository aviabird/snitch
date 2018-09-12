import MainView    from './main';
import TaxonomyIndexView from './taxonomy/index';
import TaxonomyTaxonomyView from './taxonomy/taxonomy';
import Payment_methodNewView from './payment_method/new';
import ProductProduct_categoryView from './product/product_category';
import ProductEditView from './product/edit';

// Collection of specific view modules
const views = {
  TaxonomyIndexView,
  TaxonomyTaxonomyView,
  Payment_methodNewView,
  ProductProduct_categoryView,
  ProductEditView,
};

export default function loadView(viewName) {
  return views[viewName] || MainView;
}
