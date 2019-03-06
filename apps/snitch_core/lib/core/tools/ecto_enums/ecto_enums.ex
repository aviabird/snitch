import EctoEnum
defenum(ProductStateEnum, draft: 0, active: 1, in_active: 2, deleted: 3)

defenum(OrderStateEnum,
  cart: 0,
  address: 1,
  delivery: 2,
  payment: 3,
  confirmed: 4,
  complete: 5,
  cancelled: 6
)

defenum(PackageStateEnum,
  pending: 0,
  processing: 1,
  fulfilled: 2,
  ready: 3,
  shipped: 4,
  delivered: 5,
  complete: 6
)

defenum(UserStateEnum,
  active: 0,
  deleted: 1
)

defenum(InventoryTrackingEnum,
  none: 0,
  product: 1,
  variant: 2
)

defenum(AddressTypes,
  shipping_address: 0,
  billing_address: 1,
  store_address: 2
)

defenum(OptionTypeEnum,
  swatch: 0,
  radio_button: 1,
  dropdown: 2,
  rectangle: 3
)
