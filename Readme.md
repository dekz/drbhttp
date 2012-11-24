# DRb over HTTP

```ruby
  uri = 'drbhttp://localhost:12345'
  DRb.start_service uri, {}
  DRb.thread.join()
```
